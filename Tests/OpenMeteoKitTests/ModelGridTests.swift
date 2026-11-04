import Testing
@testable import OpenMeteoKit

private let grid = LambertConformalGrid.ncepConus3km

/// Pairs 12 km inside and outside each edge, checked against the live API
/// (`ncep_rrfs_conus` and `ncep_hrrr_conus`) on 2026-11-04.
private let liveEdgeProbes: [(inside: GeoCoordinate, outside: GeoCoordinate)] = [
  (.init(latitude: 47.782, longitude: -133.888), .init(latitude: 47.895, longitude: -134.303)),
  (.init(latitude: 51.009, longitude: -118.544), .init(latitude: 51.214, longitude: -118.620)),
  (.init(latitude: 52.451, longitude: -101.752), .init(latitude: 52.660, longitude: -101.768)),
  (.init(latitude: 51.962, longitude: -84.676), .init(latitude: 52.170, longitude: -84.628)),
  (.init(latitude: 49.578, longitude: -68.435), .init(latitude: 49.779, longitude: -68.333)),
  (.init(latitude: 36.371, longitude: -128.030), .init(latitude: 36.300, longitude: -128.283)),
  (.init(latitude: 36.374, longitude: -66.981), .init(latitude: 36.303, longitude: -66.728)),
  (.init(latitude: 24.428, longitude: -94.596), .init(latitude: 24.218, longitude: -94.604)),
  (.init(latitude: 21.903, longitude: -120.059), .init(latitude: 21.701, longitude: -120.005)),
]

@Test func conusGridMatchesLiveEdges() {
  for probe in liveEdgeProbes {
    #expect(grid.contains(latitude: probe.inside.latitude, longitude: probe.inside.longitude), "\(probe.inside)")
    #expect(!grid.contains(latitude: probe.outside.latitude, longitude: probe.outside.longitude), "\(probe.outside)")
  }
}

@Test func conusGridCoversSouthernCanadaButNotTheNorth() {
  let covered = [(49.28, -123.12), (50.12, -122.95), (51.05, -114.07), (52.13, -106.67),
                 (49.90, -97.14), (43.65, -79.38), (45.50, -73.57), (44.65, -63.57)]
  let uncovered = [(53.55, -113.49), (47.56, -52.71), (61.22, -149.90), (21.30, -157.80), (19.43, -99.13)]
  for (lat, lon) in covered {
    #expect(WeatherModel.rrfs.isAvailable(latitude: lat, longitude: lon), "\(lat), \(lon)")
    #expect(WeatherModel.hrrr.isAvailable(latitude: lat, longitude: lon), "\(lat), \(lon)")
  }
  for (lat, lon) in uncovered {
    #expect(!WeatherModel.rrfs.isAvailable(latitude: lat, longitude: lon), "\(lat), \(lon)")
  }
}

@Test func conusGridOutlineStartsAtTheNorthWestCorner() {
  let outline = grid.outline(pointsPerEdge: 8)
  #expect(outline.count == 28)
  #expect(abs(outline[0].latitude - 47.842) < 0.01)
  #expect(abs(outline[0].longitude - -134.095) < 0.01)
  let southWest = outline[21]
  #expect(abs(southWest.latitude - 21.138) < 0.001)
  #expect(abs(southWest.longitude - -122.720) < 0.001)
  #expect((outline.map(\.latitude).max() ?? 0) > 52.5)
}

@Test func conusGridOutlineLiesOnTheGrid() {
  for point in grid.outline() {
    #expect(grid.contains(latitude: point.latitude, longitude: point.longitude), "\(point)")
  }
}

@Test func onlyTheNcepConusModelsHaveANativeGrid() {
  #expect(WeatherModel.allCases.filter { $0.nativeGrid != nil } == [.hrrr, .rrfs])
}
