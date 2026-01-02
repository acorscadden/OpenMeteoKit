import Testing
import Foundation
@testable import OpenMeteoKit

@Test func testClientInitialization() {
  let client = OpenMeteoClient()
  #expect(client != nil)
}

@Test func testWeatherModelEnumValues() {
  #expect(WeatherModel.ecmwfIfs025.rawValue == "ecmwf_ifs025")
  #expect(WeatherModel.ecmwfAifs025.rawValue == "ecmwf_aifs025")
  #expect(WeatherModel.iconSeamless.rawValue == "icon_seamless")
  #expect(WeatherModel.gfsSeamless.rawValue == "gfs_seamless")
  #expect(WeatherModel.hrrr.rawValue == "ncep_hrrr_conus")
  #expect(WeatherModel.nbm.rawValue == "ncep_nbm_conus")
  #expect(WeatherModel.gemGlobal.rawValue == "gem_global")
  #expect(WeatherModel.gemRegional.rawValue == "gem_regional")
  #expect(WeatherModel.gemHrdpsContinental.rawValue == "gem_hrdps_continental")
  #expect(WeatherModel.allCases.count == 9)
}

@Test func testWindSpeedUnitEnumValues() {
  #expect(WindSpeedUnit.knots.rawValue == "kn")
  #expect(WindSpeedUnit.kmh.rawValue == "kmh")
  #expect(WindSpeedUnit.mph.rawValue == "mph")
  #expect(WindSpeedUnit.ms.rawValue == "ms")
  #expect(WindSpeedUnit.allCases.count == 4)
}

@Test func testWeatherDataTypeOptionSet() {
  // Test individual options
  let windOnly: WeatherDataType = .wind
  #expect(windOnly.contains(.wind))
  #expect(!windOnly.contains(.precipitation))

  let precipOnly: WeatherDataType = .precipitation
  #expect(!precipOnly.contains(.wind))
  #expect(precipOnly.contains(.precipitation))

  // Test combined options
  let both: WeatherDataType = [.wind, .precipitation]
  #expect(both.contains(.wind))
  #expect(both.contains(.precipitation))

  // Test .all
  #expect(WeatherDataType.all.contains(.wind))
  #expect(WeatherDataType.all.contains(.precipitation))
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
  
  let gemData = firstHourly[.gemHrdpsContinental]
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

  let firstGem = firstHourly[.gemHrdpsContinental]
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

  let secondGem = secondHourly[.gemHrdpsContinental]
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

@Test func testPrecipitationDataDecoding() throws {
  let jsonString = """
  {
    "latitude": 49.25,
    "longitude": -123.1,
    "generationtime_ms": 0.5,
    "utc_offset_seconds": -28800,
    "timezone": "America/Vancouver",
    "timezone_abbreviation": "PST",
    "elevation": 70.0,
    "hourly_units": {
      "time": "iso8601",
      "wind_speed_10m_ecmwf_ifs025": "kn",
      "wind_direction_10m_ecmwf_ifs025": "°",
      "wind_gusts_10m_ecmwf_ifs025": "kn",
      "wind_speed_10m_icon_seamless": "kn",
      "wind_direction_10m_icon_seamless": "°",
      "wind_gusts_10m_icon_seamless": "kn",
      "precipitation_ecmwf_ifs025": "mm",
      "rain_ecmwf_ifs025": "mm",
      "showers_ecmwf_ifs025": "mm",
      "snowfall_ecmwf_ifs025": "cm",
      "precipitation_probability_ecmwf_ifs025": "%",
      "precipitation_icon_seamless": "mm",
      "rain_icon_seamless": "mm",
      "showers_icon_seamless": "mm",
      "snowfall_icon_seamless": "cm",
      "precipitation_probability_icon_seamless": "%"
    },
    "hourly": {
      "time": [
        "2025-12-20T08:00",
        "2025-12-20T09:00"
      ],
      "wind_speed_10m_ecmwf_ifs025": [5.0, 6.0],
      "wind_direction_10m_ecmwf_ifs025": [180, 190],
      "wind_gusts_10m_ecmwf_ifs025": [10.0, 12.0],
      "wind_speed_10m_icon_seamless": [4.5, 5.5],
      "wind_direction_10m_icon_seamless": [175, 185],
      "wind_gusts_10m_icon_seamless": [9.0, 11.0],
      "precipitation_ecmwf_ifs025": [2.5, 1.2],
      "rain_ecmwf_ifs025": [2.0, 1.0],
      "showers_ecmwf_ifs025": [0.5, 0.2],
      "snowfall_ecmwf_ifs025": [0.0, 0.0],
      "precipitation_probability_ecmwf_ifs025": [80, 60],
      "precipitation_icon_seamless": [3.0, 1.5],
      "rain_icon_seamless": [2.5, 1.2],
      "showers_icon_seamless": [0.5, 0.3],
      "snowfall_icon_seamless": [0.0, 0.0],
      "precipitation_probability_icon_seamless": [85, 65]
    }
  }
  """

  let jsonData = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let response = try decoder.decode(OpenMeteoWeatherResponse.self, from: jsonData)

  #expect(response.latitude == 49.25)
  #expect(response.longitude == -123.1)
  #expect(response.hourly.count == 2)

  // Test first hour ECMWF precipitation data
  let firstHourly = response.hourly[0]
  let ecmwfData = firstHourly[.ecmwfIfs025]
  #expect(ecmwfData != nil)
  #expect(ecmwfData?.precipitation == 2.5)
  #expect(ecmwfData?.rain == 2.0)
  #expect(ecmwfData?.showers == 0.5)
  #expect(ecmwfData?.snowfall == 0.0)
  #expect(ecmwfData?.precipitationProbability == 80)
  #expect(ecmwfData?.precipitationUnit == "mm")
  #expect(ecmwfData?.rainUnit == "mm")
  #expect(ecmwfData?.showersUnit == "mm")
  #expect(ecmwfData?.snowfallUnit == "cm")
  #expect(ecmwfData?.precipitationProbabilityUnit == "%")

  // Test first hour Icon Seamless precipitation data
  let iconData = firstHourly[.iconSeamless]
  #expect(iconData != nil)
  #expect(iconData?.precipitation == 3.0)
  #expect(iconData?.rain == 2.5)
  #expect(iconData?.showers == 0.5)
  #expect(iconData?.snowfall == 0.0)
  #expect(iconData?.precipitationProbability == 85)
  #expect(iconData?.precipitationUnit == "mm")

  // Test second hour data
  let secondHourly = response.hourly[1]
  let secondEcmwf = secondHourly[.ecmwfIfs025]
  #expect(secondEcmwf?.precipitation == 1.2)
  #expect(secondEcmwf?.rain == 1.0)
  #expect(secondEcmwf?.precipitationProbability == 60)

  let secondIcon = secondHourly[.iconSeamless]
  #expect(secondIcon?.precipitation == 1.5)
  #expect(secondIcon?.precipitationProbability == 65)
}

@Test func testPrecipitationWithNullValues() throws {
  let jsonString = """
  {
    "latitude": 49.25,
    "longitude": -123.1,
    "generationtime_ms": 0.5,
    "utc_offset_seconds": 0,
    "timezone": "GMT",
    "timezone_abbreviation": "GMT",
    "elevation": 70.0,
    "hourly_units": {
      "time": "iso8601",
      "wind_speed_10m_ecmwf_ifs025": "kn",
      "wind_direction_10m_ecmwf_ifs025": "°",
      "wind_gusts_10m_ecmwf_ifs025": "kn",
      "precipitation_ecmwf_ifs025": "mm",
      "rain_ecmwf_ifs025": "mm"
    },
    "hourly": {
      "time": [
        "2025-12-20T08:00"
      ],
      "wind_speed_10m_ecmwf_ifs025": [5.0],
      "wind_direction_10m_ecmwf_ifs025": [180],
      "wind_gusts_10m_ecmwf_ifs025": [10.0],
      "precipitation_ecmwf_ifs025": [null],
      "rain_ecmwf_ifs025": [1.5]
    }
  }
  """

  let jsonData = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let response = try decoder.decode(OpenMeteoWeatherResponse.self, from: jsonData)

  let hourly = response.hourly[0]
  let ecmwfData = hourly[.ecmwfIfs025]

  // Precipitation is null, should be nil
  #expect(ecmwfData?.precipitation == nil)
  // Rain has a value
  #expect(ecmwfData?.rain == 1.5)
  // Wind data should still work
  #expect(ecmwfData?.windSpeed == 5.0)
}

@Test func testWeatherCodeDecoding() throws {
  let jsonString = """
  {
    "latitude": 49.25,
    "longitude": -123.1,
    "generationtime_ms": 0.5,
    "utc_offset_seconds": 0,
    "timezone": "GMT",
    "timezone_abbreviation": "GMT",
    "elevation": 70.0,
    "hourly_units": {
      "time": "iso8601",
      "wind_speed_10m_ecmwf_ifs025": "kn",
      "wind_direction_10m_ecmwf_ifs025": "°",
      "wind_gusts_10m_ecmwf_ifs025": "kn",
      "wind_speed_10m_icon_seamless": "kn",
      "wind_direction_10m_icon_seamless": "°",
      "wind_gusts_10m_icon_seamless": "kn",
      "weather_code_ecmwf_ifs025": "wmo code",
      "weather_code_icon_seamless": "wmo code"
    },
    "hourly": {
      "time": [
        "2025-12-20T08:00",
        "2025-12-20T09:00"
      ],
      "wind_speed_10m_ecmwf_ifs025": [5.0, 6.0],
      "wind_direction_10m_ecmwf_ifs025": [180, 190],
      "wind_gusts_10m_ecmwf_ifs025": [10.0, 12.0],
      "wind_speed_10m_icon_seamless": [4.5, 5.5],
      "wind_direction_10m_icon_seamless": [175, 185],
      "wind_gusts_10m_icon_seamless": [9.0, 11.0],
      "weather_code_ecmwf_ifs025": [61, 66],
      "weather_code_icon_seamless": [63, 71]
    }
  }
  """

  let jsonData = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let response = try decoder.decode(OpenMeteoWeatherResponse.self, from: jsonData)

  #expect(response.hourly.count == 2)

  // Test first hour weather codes
  let firstHourly = response.hourly[0]
  let ecmwfData = firstHourly[.ecmwfIfs025]
  #expect(ecmwfData?.weatherCode == 61) // Light rain
  #expect(ecmwfData?.weatherCodeUnit == "wmo code")

  let iconData = firstHourly[.iconSeamless]
  #expect(iconData?.weatherCode == 63) // Moderate rain
  #expect(iconData?.weatherCodeUnit == "wmo code")

  // Test second hour - freezing rain and snow
  let secondHourly = response.hourly[1]
  let secondEcmwf = secondHourly[.ecmwfIfs025]
  #expect(secondEcmwf?.weatherCode == 66) // Light freezing rain

  let secondIcon = secondHourly[.iconSeamless]
  #expect(secondIcon?.weatherCode == 71) // Slight snowfall
}
