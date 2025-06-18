import Testing
import Foundation
@testable import OpenMeteoKit

@Test func testClientInitialization() {
  let client = OpenMeteoClient()
  #expect(client != nil)
}

@Test func testWeatherModelEnumValues() {
  #expect(WeatherModel.ecmwfIfs025.rawValue == "ecmwf_ifs025")
  #expect(WeatherModel.iconSeamless.rawValue == "icon_seamless")
  #expect(WeatherModel.allCases.count == 2)
}

@Test func testWindSpeedUnitEnumValues() {
  #expect(WindSpeedUnit.knots.rawValue == "kn")
  #expect(WindSpeedUnit.kmh.rawValue == "kmh")
  #expect(WindSpeedUnit.mph.rawValue == "mph")
  #expect(WindSpeedUnit.ms.rawValue == "ms")
  #expect(WindSpeedUnit.allCases.count == 4)
}

@Test func testWeatherResponseDecoding() throws {
  let jsonString = """
  {
    "latitude": 52.5,
    "longitude": 13.5,
    "generationtime_ms": 0.16367435455322266,
    "utc_offset_seconds": 0,
    "timezone": "GMT",
    "timezone_abbreviation": "GMT",
    "elevation": 38.0,
    "hourly_units": {
      "time": "iso8601",
      "wind_speed_10m_ecmwf_ifs025": "kn",
      "wind_direction_10m_ecmwf_ifs025": "°",
      "wind_gusts_10m_ecmwf_ifs025": "kn",
      "wind_speed_10m_icon_seamless": "kn",
      "wind_direction_10m_icon_seamless": "°",
      "wind_gusts_10m_icon_seamless": "kn"
    },
    "hourly": {
      "time": [
        "2025-06-18T00:00",
        "2025-06-18T01:00"
      ],
      "wind_speed_10m_ecmwf_ifs025": [3.8, 3.8],
      "wind_direction_10m_ecmwf_ifs025": [240, 249],
      "wind_gusts_10m_ecmwf_ifs025": [7.0, 7.6],
      "wind_speed_10m_icon_seamless": [1.6, 2.5],
      "wind_direction_10m_icon_seamless": [256, 274],
      "wind_gusts_10m_icon_seamless": [2.9, 4.9]
    }
  }
  """

  let jsonData = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()

  let response = try decoder.decode(WeatherResponse.self, from: jsonData)

  #expect(response.latitude == 52.5)
  #expect(response.longitude == 13.5)
  #expect(response.timezone == "GMT")
  #expect(response.elevation == 38.0)

  #expect(response.hourlyUnits.time == "iso8601")
  #expect(response.hourlyUnits.windSpeed10mEcmwfIfs025 == "kn")

  #expect(response.hourly.time.count == 2)
  #expect(response.hourly.time[0] == "2025-06-18T00:00")
  #expect(response.hourly.windSpeed10mEcmwfIfs025?[0] == 3.8)
  #expect(response.hourly.windDirection10mEcmwfIfs025?[0] == 240)
}

@Test func testWeatherDataPointsGeneration() throws {
  let jsonString = """
  {
    "latitude": 52.5,
    "longitude": 13.5,
    "generationtime_ms": 0.16367435455322266,
    "utc_offset_seconds": 0,
    "timezone": "GMT",
    "timezone_abbreviation": "GMT",
    "elevation": 38.0,
    "hourly_units": {
      "time": "iso8601",
      "wind_speed_10m_ecmwf_ifs025": "kn",
      "wind_direction_10m_ecmwf_ifs025": "°",
      "wind_gusts_10m_ecmwf_ifs025": "kn",
      "wind_speed_10m_icon_seamless": "kn",
      "wind_direction_10m_icon_seamless": "°",
      "wind_gusts_10m_icon_seamless": "kn"
    },
    "hourly": {
      "time": [
        "2025-06-18T00:00",
        "2025-06-18T01:00"
      ],
      "wind_speed_10m_ecmwf_ifs025": [3.8, 3.8],
      "wind_direction_10m_ecmwf_ifs025": [240, 249],
      "wind_gusts_10m_ecmwf_ifs025": [7.0, 7.6],
      "wind_speed_10m_icon_seamless": [1.6, 2.5],
      "wind_direction_10m_icon_seamless": [256, 274],
      "wind_gusts_10m_icon_seamless": [2.9, 4.9]
    }
  }
  """

  let jsonData = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let response = try decoder.decode(WeatherResponse.self, from: jsonData)

  let dataPoints = response.hourly.weatherDataPoints

  #expect(dataPoints.count == 2)

  let firstPoint = dataPoints[0]
  #expect(firstPoint.time == "2025-06-18T00:00")
  #expect(firstPoint.ecmwfIfs025.windSpeed == 3.8)
  #expect(firstPoint.ecmwfIfs025.windDirection == 240)
  #expect(firstPoint.ecmwfIfs025.windGusts == 7.0)
  #expect(firstPoint.iconSeamless.windSpeed == 1.6)
  #expect(firstPoint.iconSeamless.windDirection == 256)
  #expect(firstPoint.iconSeamless.windGusts == 2.9)
}

@Test func testWeatherDataPointDateParsing() {
  let dataPoint = WeatherDataPoint(
    time: "2025-06-18T12:30",
    ecmwfIfs025: WeatherModelData(windSpeed: 10.0, windDirection: 180, windGusts: 15.0),
    iconSeamless: WeatherModelData(windSpeed: 9.5, windDirection: 175, windGusts: 14.5)
  )

  let date = dataPoint.date
  #expect(date != nil)

  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(abbreviation: "GMT")!
  let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date!)

  #expect(components.year == 2025)
  #expect(components.month == 6)
  #expect(components.day == 18)
  #expect(components.hour == 12)
  #expect(components.minute == 30)
}
