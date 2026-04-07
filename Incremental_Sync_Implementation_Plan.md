# Incremental Sync Implementation Plan - Using FlxPoint `updatedAfter` Parameter

## Overview

The FlxPoint API supports an `updatedAfter` parameter that allows filtering inventory variants by their last modified date. This enables true incremental sync where we only fetch and process records that have actually changed since the last sync.

**API Documentation:** https://flxpoint.stoplight.io/docs/flxpoint-api/a9e03672ef166-get-inventory-variants

**Parameter:** `updatedAfter` (string<date-time>)
- Only retrieves inventory records that have been updated after the date specified
- Format: ISO 8601 date-time string

## Current State Analysis

### Current Implementation
- `SyncInventory()` calls `DeleteAll()` to clear all records
- Fetches ALL variants from FlxPoint API (no filtering)
- Processes all variants regardless of whether they changed
- No tracking of what was actually modified

### Current Data Available
- `FlxPointInventory."Last Modified Date"` - Last modified date from FlxPoint
- `FlxPointInventory."Last Sync Date"` - When BC last synced this record
- Both fields are already being populated in `ProcessInventoryVariant()`

## Implementation Strategy

### Phase 1: Add Sync Tracking to Setup Table

#### 1.1 Add Fields to FlxPoint Setup Table
**Table:** `FlxPoint Setup` (Tab50700)

**New Fields:**
- `"Last Full Sync Date"` (DateTime)
  - Tracks when the last full sync (all records) was performed
  - Used to determine if we need a full sync vs incremental
  
- `"Last Incremental Sync Date"` (DateTime)
  - Tracks the most recent `updatedAfter` timestamp used
  - This becomes the `updatedAfter` parameter for next sync
  
- `"Sync Mode"` (Option: "Full", "Incremental", "Auto")
  - Allows manual control of sync type
  - "Auto" = Use incremental if last sync was recent, otherwise full

- `"Incremental Sync Threshold (Days)"` (Integer, default: 7)
  - If last full sync was more than X days ago, force full sync
  - Prevents incremental sync from missing records if sync was down for a while

#### 1.2 Benefits
- User can control sync behavior
- System can auto-detect when full sync is needed
- Audit trail of sync history

### Phase 2: Modify SyncInventory() Procedure

#### 2.1 Determine Sync Type
**Logic:**
```
IF SyncMode = "Full" THEN
    PerformFullSync()
ELSE IF SyncMode = "Incremental" THEN
    PerformIncrementalSync()
ELSE IF SyncMode = "Auto" THEN
    IF (CurrentDateTime - LastFullSyncDate) > IncrementalSyncThreshold THEN
        PerformFullSync()
    ELSE
        PerformIncrementalSync()
```

#### 2.2 Full Sync Implementation
**Behavior:**
- Use existing `DeleteAll()` approach
- Fetch ALL variants (no `updatedAfter` parameter)
- Update `Last Full Sync Date` after completion
- Reset `Last Incremental Sync Date`

**When to Use:**
- First time sync
- Manual full sync requested
- Last full sync was too long ago (threshold exceeded)
- After system errors or data corruption

#### 2.3 Incremental Sync Implementation
**Behavior:**
- Do NOT call `DeleteAll()`
- Use `updatedAfter` parameter with `Last Incremental Sync Date`
- Only fetch variants modified since last sync
- Process fetched variants:
  - If record exists: Update it
  - If record doesn't exist: Insert it (new variant in FlxPoint)
- Update `Last Incremental Sync Date` to current time after completion
- Handle deleted variants (see Phase 3)

**API Call:**
```
GET https://api.flxpoint.com/inventory/variants?page=1&pageSize=100&updatedAfter=2024-01-15T10:30:00Z
```

**Benefits:**
- Only processes changed records
- Much faster for frequent syncs
- Reduces API load
- Reduces database operations

### Phase 3: Handle Deleted Variants

#### 3.1 Problem
Incremental sync only fetches variants that were updated. Variants deleted in FlxPoint won't appear in the response, so they'll remain in BC.

#### 3.2 Solution Options

**Option A: Mark and Cleanup (Recommended)**
1. Before incremental sync: Mark all existing records with a timestamp
2. During sync: Clear mark for records that are updated/inserted
3. After sync: Delete records still marked (older than threshold)
4. Threshold: Only delete if mark is older than X days (safety buffer)

**Option B: Periodic Full Sync**
- Run full sync weekly/monthly to catch deletions
- Incremental sync handles daily changes
- Simpler but less real-time

**Option C: Deleted Variants API Endpoint**
- Check if FlxPoint has a "deleted variants" endpoint
- Query separately for deleted variants
- Delete those records from BC

**Option D: Archive Flag**
- Don't delete, just mark as archived
- FlxPoint API might return `archived: true` for deleted items
- Filter archived items in BC UI instead of deleting

#### 3.3 Recommended Approach
Use **Option A** with a 7-day safety threshold:
- Mark all records before sync
- Clear mark when variant is found in FlxPoint response
- After sync completes, delete records marked > 7 days ago
- This handles:
  - Recently deleted variants (kept for 7 days)
  - Variants that weren't in incremental response but still exist (kept)
  - Truly deleted variants (removed after 7 days)

### Phase 4: API Integration Changes

#### 4.1 Modify API Request Building
**Current:**
```al
RequestMessage.SetRequestUri('https://api.flxpoint.com/inventory/variants?page=' + Format(Page) + '&pageSize=' + Format(PageSize));
```

**New:**
```al
Uri := 'https://api.flxpoint.com/inventory/variants?page=' + Format(Page) + '&pageSize=' + Format(PageSize);
IF IncrementalSync THEN BEGIN
    UpdatedAfterDate := Format(LastIncrementalSyncDate, 0, 9); // ISO 8601 format
    Uri += '&updatedAfter=' + UpdatedAfterDate;
END;
RequestMessage.SetRequestUri(Uri);
```

#### 4.2 Date Format Handling
- FlxPoint expects ISO 8601 format: `YYYY-MM-DDTHH:mm:ssZ`
- BC DateTime format needs conversion
- Use `Format(DateTime, 0, 9)` or custom formatting function
- Ensure timezone is UTC (Z suffix)

#### 4.3 Pagination with Filter
- `updatedAfter` filter applies to all pages
- Pagination logic remains the same
- All pages will only contain filtered results

### Phase 5: Error Handling and Recovery

#### 5.1 Sync Failure Scenarios

**Scenario 1: API Returns No Records**
- Could mean: No changes since last sync (good)
- Could mean: API error or date format issue (bad)
- **Handling:** Log the request, verify date format, check API response

**Scenario 2: Partial Sync Failure**
- Sync starts but fails mid-process
- Some records updated, some not
- **Handling:** 
  - Don't update `Last Incremental Sync Date` until sync completes
  - Use transaction/checkpoint approach
  - Allow resume from last successful page

**Scenario 3: Date Format Error**
- Invalid date format causes API to reject request
- **Handling:** 
  - Validate date format before API call
  - Fall back to full sync if incremental fails
  - Log error for debugging

**Scenario 4: Clock Skew**
- System clock changed between syncs
- `updatedAfter` date might be in future
- **Handling:**
  - Validate `updatedAfter` is not in future
  - If in future, use last known good date or full sync

#### 5.2 Recovery Mechanisms

**Automatic Fallback:**
- If incremental sync returns 0 records unexpectedly → Trigger full sync
- If incremental sync fails → Log error, allow manual full sync
- If date format invalid → Use full sync, log error

**Manual Override:**
- User can force full sync from page action
- User can reset sync dates if needed
- User can adjust incremental threshold

### Phase 6: UI/UX Enhancements

#### 6.1 Page Actions
**On FlxPoint Inventory Page:**
- "Sync All Inventory" (existing - full sync)
- "Sync Recent Changes" (new - incremental sync)
- "Reset Sync Dates" (new - admin function)

#### 6.2 Setup Page Fields
**On FlxPoint Setup Page:**
- Display `Last Full Sync Date` (read-only)
- Display `Last Incremental Sync Date` (read-only)
- `Sync Mode` dropdown (Full/Incremental/Auto)
- `Incremental Sync Threshold (Days)` field
- "Run Full Sync Now" action
- "Run Incremental Sync Now" action

#### 6.3 Progress Indicators
- Show sync type (Full vs Incremental)
- Show records processed vs total
- Show estimated time remaining
- Show last sync date/time

### Phase 7: Logging and Telemetry

#### 7.1 Sync Metrics
**Log for each sync:**
- Sync type (Full/Incremental)
- Start time
- End time
- Duration
- Records fetched from API
- Records inserted
- Records updated
- Records deleted (if any)
- API pages processed
- Any errors encountered

#### 7.2 Telemetry Events
- `FlxPoint-InvSync-Incremental-Start`
- `FlxPoint-InvSync-Incremental-Complete`
- `FlxPoint-InvSync-Incremental-Error`
- `FlxPoint-InvSync-Full-Start`
- `FlxPoint-InvSync-Full-Complete`

#### 7.3 Performance Tracking
- Compare incremental vs full sync times
- Track API response times
- Monitor database operation counts
- Track memory usage

### Phase 8: Testing Strategy

#### 8.1 Unit Tests
- Test date format conversion (BC DateTime → ISO 8601)
- Test sync type determination logic
- Test API URL building with/without `updatedAfter`
- Test edge cases (empty dates, future dates, etc.)

#### 8.2 Integration Tests
- Test incremental sync with real API
- Test full sync still works
- Test sync mode switching
- Test error recovery

#### 8.3 Scenario Tests
**Scenario 1: First Sync**
- No previous sync date
- Should perform full sync
- Should set both sync dates

**Scenario 2: Daily Incremental Sync**
- Last sync was yesterday
- Only 10 variants changed
- Should fetch only those 10
- Should update only those 10 records

**Scenario 3: Sync After Long Gap**
- Last sync was 30 days ago
- Should perform full sync (threshold exceeded)
- Should reset sync dates

**Scenario 4: Manual Full Sync**
- User clicks "Sync All"
- Should ignore incremental settings
- Should perform full sync
- Should update full sync date

**Scenario 5: Deleted Variant**
- Variant exists in BC
- Variant deleted in FlxPoint
- Incremental sync doesn't return it
- Should be marked for deletion (after threshold)

### Phase 9: Migration Plan

#### 9.1 Data Migration
**For existing installations:**
- Set `Last Full Sync Date` = Current DateTime (assume just did full sync)
- Set `Last Incremental Sync Date` = Current DateTime
- Set `Sync Mode` = "Auto" (default)
- Set `Incremental Sync Threshold` = 7 days (default)

#### 9.2 Backward Compatibility
- If new fields don't exist, default to full sync
- Gracefully handle missing setup fields
- Don't break existing sync functionality

#### 9.3 Rollout Strategy
1. **Phase 1:** Add fields, default to full sync (no behavior change)
2. **Phase 2:** Add incremental sync code, disabled by default
3. **Phase 3:** Enable incremental sync for testing
4. **Phase 4:** Make incremental sync default for new installs
5. **Phase 5:** Enable auto mode for all users

### Phase 10: Performance Expectations

#### 10.1 Full Sync (Current)
- 10,000 variants: ~30-60 minutes
- API calls: ~100 (pagination)
- Database operations: ~20,000 (delete + insert)

#### 10.2 Incremental Sync (Expected)
**Scenario A: 100 variants changed (1%)**
- API calls: ~1-2 (pagination)
- Database operations: ~100 (updates only)
- Time: ~1-2 minutes (95% faster)

**Scenario B: 1,000 variants changed (10%)**
- API calls: ~10 (pagination)
- Database operations: ~1,000 (updates only)
- Time: ~5-10 minutes (80% faster)

**Scenario C: 5,000 variants changed (50%)**
- API calls: ~50 (pagination)
- Database operations: ~5,000 (updates only)
- Time: ~15-25 minutes (50% faster)

#### 10.3 API Load Reduction
- Full sync: Always fetches all variants
- Incremental sync: Only fetches changed variants
- **Reduction:** 90-99% fewer API calls for typical daily syncs

## Implementation Checklist

### Setup Table Changes
- [ ] Add `Last Full Sync Date` field
- [ ] Add `Last Incremental Sync Date` field
- [ ] Add `Sync Mode` option field
- [ ] Add `Incremental Sync Threshold (Days)` field
- [ ] Update setup page to show/edit new fields

### Code Changes
- [ ] Modify `SyncInventory()` to determine sync type
- [ ] Create `PerformFullSync()` procedure
- [ ] Create `PerformIncrementalSync()` procedure
- [ ] Modify API request building to include `updatedAfter`
- [ ] Add date format conversion (BC DateTime → ISO 8601)
- [ ] Implement deleted variant handling
- [ ] Add error handling and recovery
- [ ] Update telemetry logging

### UI Changes
- [ ] Add "Sync Recent Changes" action to inventory page
- [ ] Update setup page with new fields
- [ ] Add sync status display
- [ ] Add progress indicators

### Testing
- [ ] Unit tests for date formatting
- [ ] Unit tests for sync type determination
- [ ] Integration tests with real API
- [ ] Scenario testing (all scenarios above)
- [ ] Performance testing
- [ ] Error handling testing

### Documentation
- [ ] Update user guide with incremental sync
- [ ] Update technical documentation
- [ ] Add setup instructions
- [ ] Add troubleshooting guide

## Risk Assessment

### Low Risk
- Adding new fields to setup table
- UI changes
- Logging enhancements

### Medium Risk
- Date format conversion (timezone issues)
- Deleted variant handling (data loss risk)
- API parameter integration

### High Risk
- Changing core sync logic
- Handling edge cases (clock skew, partial failures)
- Migration of existing data

## Success Criteria

1. ✅ Incremental sync only fetches changed variants
2. ✅ Full sync still works as before
3. ✅ Sync mode can be controlled by user
4. ✅ Deleted variants are handled correctly
5. ✅ Performance improvement: 50-95% faster for typical syncs
6. ✅ No data loss during sync
7. ✅ Error recovery works correctly
8. ✅ Backward compatible with existing installations

## Timeline Estimate

- **Phase 1-2 (Setup & Core Logic):** 2-3 days
- **Phase 3 (Deleted Variants):** 1-2 days
- **Phase 4 (API Integration):** 1 day
- **Phase 5 (Error Handling):** 1-2 days
- **Phase 6 (UI):** 1 day
- **Phase 7 (Logging):** 0.5 days
- **Phase 8 (Testing):** 2-3 days
- **Phase 9 (Migration):** 0.5 days
- **Phase 10 (Performance Validation):** 1 day

**Total:** ~10-14 days of development

## Conclusion

Implementing incremental sync using FlxPoint's `updatedAfter` parameter will:
- **Dramatically improve performance** for daily syncs (50-95% faster)
- **Reduce API load** (90-99% fewer API calls)
- **Reduce database operations** (only update changed records)
- **Improve user experience** (faster syncs, less waiting)
- **Maintain data safety** (no DeleteAll, can recover from failures)

The implementation is straightforward thanks to FlxPoint's built-in API support for date filtering. The main complexity is handling deleted variants and ensuring robust error handling.

