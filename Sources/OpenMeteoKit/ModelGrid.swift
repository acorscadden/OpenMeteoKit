//
//  ModelGrid.swift
//  OpenMeteoKit
//

import Foundation

/// A latitude/longitude pair in degrees.
public struct GeoCoordinate: Equatable, Sendable {
  public let latitude: Double
  public let longitude: Double

  public init(latitude: Double, longitude: Double) {
    self.latitude = latitude
    self.longitude = longitude
  }
}

/// A model's native Lambert-conformal grid on a spherical earth, as Open-Meteo
/// publishes it in `https://api.open-meteo.com/data/<domain>/static/meta.json`.
///
/// Projecting onto the grid gives the model's true footprint, whose edges are
/// curves in latitude/longitude rather than a box.
public struct LambertConformalGrid: Sendable {
  public let standardParallel: Double
  public let centralMeridian: Double
  public let firstPoint: GeoCoordinate
  public let spacingMeters: Double
  public let columns: Int
  public let rows: Int

  private static let earthRadius = 6_371_229.0

  /// NCEP's 3 km CONUS grid, shared by HRRR and RRFS. 1799 × 1059 points from
  /// 21.14°N 122.72°W; its north edge bows up to about 52.6°N over Manitoba.
  public static let ncepConus3km = LambertConformalGrid(
    standardParallel: 38.5,
    centralMeridian: -97.5,
    firstPoint: GeoCoordinate(latitude: 21.138123, longitude: -122.719528),
    spacingMeters: 3000,
    columns: 1799,
    rows: 1059
  )

  public init(
    standardParallel: Double, centralMeridian: Double, firstPoint: GeoCoordinate,
    spacingMeters: Double, columns: Int, rows: Int
  ) {
    self.standardParallel = standardParallel
    self.centralMeridian = centralMeridian
    self.firstPoint = firstPoint
    self.spacingMeters = spacingMeters
    self.columns = columns
    self.rows = rows
  }

  /// Whether the coordinate falls on the grid, within half a cell of its edge.
  public func contains(latitude: Double, longitude: Double) -> Bool {
    let (column, row) = gridIndex(latitude: latitude, longitude: longitude)
    return column >= -0.5 && column <= Double(columns) - 0.5
      && row >= -0.5 && row <= Double(rows) - 0.5
  }

  /// The grid's perimeter, clockwise from the north-west corner, with
  /// `pointsPerEdge` points along each side.
  public func outline(pointsPerEdge: Int = 32) -> [GeoCoordinate] {
    let steps = max(pointsPerEdge, 2) - 1
    let lastColumn = Double(columns - 1)
    let lastRow = Double(rows - 1)
    let fractions = (0..<steps).map { Double($0) / Double(steps) }
    let north = fractions.map { (lastColumn * $0, lastRow) }
    let east = fractions.map { (lastColumn, lastRow * (1 - $0)) }
    let south = fractions.map { (lastColumn * (1 - $0), 0.0) }
    let west = fractions.map { (0.0, lastRow * $0) }
    return (north + east + south + west).map { coordinate(column: $0.0, row: $0.1) }
  }

  // MARK: - Projection

  private var cone: Double { sin(Self.radians(standardParallel)) }

  private var scale: Double {
    let phi = Self.radians(standardParallel)
    return cos(phi) * pow(tan(.pi / 4 + phi / 2), cone) / cone
  }

  private func radius(atLatitude latitude: Double) -> Double {
    Self.earthRadius * scale / pow(tan(.pi / 4 + Self.radians(latitude) / 2), cone)
  }

  private func project(latitude: Double, longitude: Double) -> (x: Double, y: Double) {
    var deltaLongitude = longitude - centralMeridian
    deltaLongitude -= 360 * (deltaLongitude / 360).rounded()
    let theta = cone * Self.radians(deltaLongitude)
    let rho = radius(atLatitude: latitude)
    return (rho * sin(theta), radius(atLatitude: standardParallel) - rho * cos(theta))
  }

  private func gridIndex(latitude: Double, longitude: Double) -> (column: Double, row: Double) {
    let origin = project(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
    let point = project(latitude: latitude, longitude: longitude)
    return ((point.x - origin.x) / spacingMeters, (point.y - origin.y) / spacingMeters)
  }

  private func coordinate(column: Double, row: Double) -> GeoCoordinate {
    let origin = project(latitude: firstPoint.latitude, longitude: firstPoint.longitude)
    let x = origin.x + column * spacingMeters
    let dy = radius(atLatitude: standardParallel) - (origin.y + row * spacingMeters)
    let rho = hypot(x, dy)
    let latitude = 2 * atan(pow(Self.earthRadius * scale / rho, 1 / cone)) - .pi / 2
    let longitude = Self.radians(centralMeridian) + atan2(x, dy) / cone
    return GeoCoordinate(latitude: Self.degrees(latitude), longitude: Self.degrees(longitude))
  }

  private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
  private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
}

extension WeatherModel {
  /// The model's projected native grid, when its footprint isn't a lat/lon box.
  public var nativeGrid: LambertConformalGrid? {
    switch self {
    case .hrrr, .rrfs: return .ncepConus3km
    default: return nil
    }
  }
}
