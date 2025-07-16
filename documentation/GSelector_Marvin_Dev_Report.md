# GSelector Marvin Service - Critical Bug Report

**Date:** July 16, 2025  
**Reporter:** Cameron St. Clair - Southern Cross Austereo  
**Environment:** Production - QLD-GSLIIS-002  
**Version:** 5.1.1.420  

## Executive Summary
The Marvin service experiences deadlock conditions that render it unresponsive, requiring manual restart to restore client connectivity. This is a **production-critical issue** affecting business operations.

## Bug Details

### Primary Issue: Cache Write Lock Deadlock
**Location:** `RCS.GSelector.Marvin.Services.Cache.Impl.CachedDataSource.GetWriteLock()`  
**Severity:** Critical  
**Frequency:** Intermittent (overnight periods)  

#### Technical Description
Multiple threads become deadlocked when attempting to acquire write locks on the cache system. The issue manifests as:

```
Exception: GetWriteLock(6) Timeout.
Stack Trace:
  at RCS.GSelector.Marvin.Services.Cache.Impl.CachedDataSouce.<>c__DisplayClass16_0.<GetWriteLock>b__0()
  at RCS.GSelector.Core.Helpers.Retry.Do[T](Func`1 action, TimeSpan retryInterval, Int32 retryCount, Boolean increasingWaitTimes, Func`2 results, Boolean returnLastResult)
```

#### Observed Pattern
- Multiple threads (TIDs: 18991, 20467, 20499, 20513, 20514) simultaneously fail to acquire write locks
- Each thread retries 5 times with 6-second timeouts before failing
- Deadlock persists for 30+ minutes until service restart
- Issue occurs during off-peak hours (likely triggered by batch operations)

### Secondary Issue: WCF Serialization Exception
**Location:** `RCS.GSelector.Client.Helpers.Settings.SettingsValueObject`  
**Severity:** High  
**Error Type:** `InvalidDataContractException`  

#### Technical Description
```
InvalidDataContractException: Type 'RCS.GSelector.Client.Helpers.Settings.SettingsValueObject' cannot be serialized. Consider marking it with the DataContractAttribute attribute, and marking all of its members you want serialized with the DataMemberAttribute attribute.
```

This affects WSDL metadata generation and client connectivity.

### Tertiary Issue: Database Timeouts
**Location:** `RCS.GoalSelector.Services.Data.StationData.GetStationInfo()`  
**Severity:** Medium  
**Error Type:** `SqlException: Execution Timeout Expired`

## Reproduction Steps
1. Service runs normally during regular operations
2. During overnight batch processing or high-load periods
3. Multiple threads attempt cache write operations simultaneously
4. Write lock contention leads to deadlock
5. Service becomes unresponsive to client connections
6. Manual service restart required to restore functionality

## Impact Analysis
- **Service Outage:** 30+ minutes of complete unavailability
- **Client Impact:** All remote users unable to connect
- **Business Impact:** Production downtime during business hours
- **Recovery:** Requires manual administrative intervention

## Recommended Development Actions

### Critical Priority (Immediate)
1. **Fix Cache Deadlock**
   - Review write lock acquisition logic in `CachedDataSource.GetWriteLock()`
   - Implement deadlock detection and recovery mechanism
   - Add timeout handling for write lock operations
   - Consider implementing lock ordering to prevent circular dependencies

2. **WCF Serialization Fix**
   - Add `[DataContract]` attribute to `SettingsValueObject` class
   - Add `[DataMember]` attributes to all serializable properties
   - Test WSDL metadata generation after changes

### High Priority (Short-term)
3. **Database Performance**
   - Optimize `StationData.GetStationInfo()` query performance
   - Review database connection pooling configuration
   - Implement appropriate query timeouts

4. **Enhanced Logging**
   - Add detailed logging around cache lock acquisition/release
   - Log thread IDs and lock states for debugging
   - Implement performance counters for cache operations

### Medium Priority (Long-term)
5. **Architecture Review**
   - Evaluate current cache locking strategy
   - Consider implementing async cache operations
   - Review thread pool configuration and usage

## Code Investigation Areas

### Files to Review
- `RCS.GSelector.Marvin.Services.Cache.Impl.CachedDataSource`
- `RCS.GSelector.Core.Helpers.Retry.cs` (line 110)
- `RCS.GSelector.Client.Helpers.Settings.SettingsValueObject`
- `RCS.GoalSelector.Services.Data.StationData.cs` (line 3543)

### Key Methods
- `CachedDataSource.GetWriteLock()`
- `Retry.Do[T]()` method
- `StationData.GetStationInfo()`

## Testing Requirements
1. **Load Testing:** Simulate multiple concurrent cache write operations
2. **Stress Testing:** Test behavior under high thread contention
3. **Timeout Testing:** Verify proper timeout handling and recovery
4. **Integration Testing:** Ensure WCF serialization fixes don't break existing functionality

## Monitoring Needs
- Cache write lock acquisition times
- Thread pool utilization
- Database connection pool status
- Cache hit/miss ratios
- Memory usage patterns

## Additional Information
- Log files available for detailed analysis
- Issue reproducible in production environment
- Affects GSelector version 5.1.1.420
- Server: QLD-GSLIIS-002 (Windows Server environment)

---

**Contact:** Cameron St. Clair - Southern Cross Austereo  
**Priority:** Critical - Production Impact  
**Expected Response:** 24-48 hours for initial assessment
