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
  #expect(WeatherModel.gem_hrdps_continental.rawValue == "gem_hrdps_continental")
  #expect(WeatherModel.allCases.count == 3)
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
      "wind_gusts_10m_icon_seamless": "kn",
      "wind_speed_10m_gem_hrdps_continental": "mph",
      "wind_direction_10m_gem_hrdps_continental": "°",
      "wind_gusts_10m_gem_hrdps_continental": "mph"
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
      "wind_gusts_10m_icon_seamless": [2.9, 4.9],
      "wind_speed_10m_gem_hrdps_continental": [5.5, 6.1],
      "wind_direction_10m_gem_hrdps_continental": [230, 235],
      "wind_gusts_10m_gem_hrdps_continental": [10.0, 11.5]
    }
  }
  """

  let jsonData = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()

  let response = try decoder.decode(OpenMeteoWeatherResponse.self, from: jsonData)

  #expect(response.latitude == 52.5)
  #expect(response.longitude == 13.5)
  #expect(response.timezone == "GMT")
  #expect(response.elevation == 38.0)

  #expect(response.hourly.count == 2)

  let firstHourly = response.hourly[0]
  #expect(firstHourly.time != Date(timeIntervalSince1970: 0)) 

  let ecmwfData = firstHourly[.ecmwfIfs025]
  #expect(ecmwfData != nil)
  #expect(ecmwfData?.windSpeed == 3.8)
  #expect(ecmwfData?.windDirection == 240)
  #expect(ecmwfData?.windGusts == 7.0)
  #expect(ecmwfData?.windSpeedUnit == "kn")
  #expect(ecmwfData?.windDirectionUnit == "°")
  #expect(ecmwfData?.windGustsUnit == "kn")

  let iconData = firstHourly[.iconSeamless]
  #expect(iconData != nil)
  #expect(iconData?.windSpeed == 1.6)
  #expect(iconData?.windDirection == 256)
  #expect(iconData?.windGusts == 2.9)
  #expect(iconData?.windSpeedUnit == "kn")
  
  let gemData = firstHourly[.gem_hrdps_continental]
  #expect(gemData != nil)
  #expect(gemData?.windSpeed == 5.5)
  #expect(gemData?.windDirection == 230)
  #expect(gemData?.windGusts == 10.0)
  #expect(gemData?.windSpeedUnit == "mph")
  #expect(gemData?.windDirectionUnit == "°")
  #expect(gemData?.windGustsUnit == "mph")
}

@Test func testHourlyDataModelAccess() throws {
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
      "wind_gusts_10m_icon_seamless": "kn",
      "wind_speed_10m_gem_hrdps_continental": "ms",
      "wind_direction_10m_gem_hrdps_continental": "°",
      "wind_gusts_10m_gem_hrdps_continental": "ms"
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
      "wind_gusts_10m_icon_seamless": [2.9, 4.9],
      "wind_speed_10m_gem_hrdps_continental": [2.0, 2.2],
      "wind_direction_10m_gem_hrdps_continental": [220, 225],
      "wind_gusts_10m_gem_hrdps_continental": [4.0, 4.5]
    }
  }
  """

  let jsonData = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let response = try decoder.decode(OpenMeteoWeatherResponse.self, from: jsonData)

  #expect(response.hourly.count == 2)

  let firstHourly = response.hourly[0]
  let secondHourly = response.hourly[1]

  let firstEcmwf = firstHourly[.ecmwfIfs025]
  #expect(firstEcmwf?.windSpeed == 3.8)
  #expect(firstEcmwf?.windDirection == 240)
  #expect(firstEcmwf?.windGusts == 7.0)

  let firstIcon = firstHourly[.iconSeamless]
  #expect(firstIcon?.windSpeed == 1.6)
  #expect(firstIcon?.windDirection == 256)
  #expect(firstIcon?.windGusts == 2.9)

  let firstGem = firstHourly[.gem_hrdps_continental]
  #expect(firstGem?.windSpeed == 2.0)
  #expect(firstGem?.windDirection == 220)
  #expect(firstGem?.windGusts == 4.0)

  let secondEcmwf = secondHourly[.ecmwfIfs025]
  #expect(secondEcmwf?.windSpeed == 3.8)
  #expect(secondEcmwf?.windDirection == 249)
  #expect(secondEcmwf?.windGusts == 7.6)

  let secondIcon = secondHourly[.iconSeamless]
  #expect(secondIcon?.windSpeed == 2.5)
  #expect(secondIcon?.windDirection == 274)
  #expect(secondIcon?.windGusts == 4.9)

  let secondGem = secondHourly[.gem_hrdps_continental]
  #expect(secondGem?.windSpeed == 2.2)
  #expect(secondGem?.windDirection == 225)
  #expect(secondGem?.windGusts == 4.5)
}

@Test func testDateParsing() throws {
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
      "wind_gusts_10m_ecmwf_ifs025": "kn"
    },
    "hourly": {
      "time": [
        "2025-06-18T12:30"
      ],
      "wind_speed_10m_ecmwf_ifs025": [10.0],
      "wind_direction_10m_ecmwf_ifs025": [180],
      "wind_gusts_10m_ecmwf_ifs025": [15.0]
    }
  }
  """

  let jsonData = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let response = try decoder.decode(OpenMeteoWeatherResponse.self, from: jsonData)

  let hourlyData = response.hourly[0]
  let date = hourlyData.time

  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(abbreviation: "GMT")!
  let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

  #expect(components.year == 2025)
  #expect(components.month == 6)
  #expect(components.day == 18)
  #expect(components.hour == 12)
  #expect(components.minute == 30)
}
