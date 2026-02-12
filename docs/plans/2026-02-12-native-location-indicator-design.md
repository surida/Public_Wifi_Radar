# Native Location Indicator Design

## Problem
WiFi 위치를 따라갈 때 방향을 알기 어려움. 현재 앱은 수동으로 그린 정적 파란 원(Circle)만 표시하여, 방향 표시/펄스 애니메이션 없음.

## Solution
Google Maps SDK의 네이티브 `myLocationEnabled` 기능을 활성화하여 파란 점 + 펄스 애니메이션 + 방향 콘을 표시.

## Changes

### Remove
- `_circles` state variable
- `_updateLocationCircle()` method
- `circles` property from `GoogleMap` widget
- `_updateLocationCircle()` call from `_startPositionStream()`

### Modify
- `myLocationEnabled: false` → `true`

### Keep
- `myLocationButtonEnabled: false` (custom FAB used instead)
- `_currentPosition` + `_positionStream` (needed for FAB)
- `_hasLocationPermission` (FAB visibility condition)
- `_moveToMyLocation()` (custom FAB action)

## Affected Files
- `lib/screens/map_screen.dart` (single file change)
