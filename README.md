# OpenMeteoKit

A Swift package for fetching weather data from the Open-Meteo API, with support for multiple weather models.

[![Swift](https://github.com/acorscadden/OpenMeteoKit/actions/workflows/swift.yml/badge.svg)](https://github.com/acorscadden/OpenMeteoKit/actions/workflows/swift.yml)

## Features

- 🌡️ **Temperature Data**: Fetch 2-meter air temperature
- 🌪️ **Wind Data**: Fetch wind speed, direction, and gusts
- 🌧️ **Precipitation Data**: Fetch precipitation, rain, showers, snowfall, and probability
- 🌤️ **Weather Codes**: WMO weather condition codes
- 🔄 **9 Weather Models**: ECMWF IFS025, ECMWF AIFS025, ICON Seamless, GFS Seamless, HRRR, NBM, GEM Global, GEM Regional, GEM HRDPS Continental
- 📱 **Modern Swift**: Built with async/await and modern Swift patterns
- 🎯 **Type Safe**: Fully typed responses with optional handling
- 🗺️ **Model Availability**: Check which models cover specific coordinates

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 6.0+

## Installation

### Swift Package Manager

Add OpenMeteoKit to your project through Xcode:

1. File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/acorscadden/OpenMeteoKit.git`

## Usage

### Basic Usage

```swift
import OpenMeteoKit

let client = OpenMeteoClient()

// Fetch weather data for a location
let response = try await client.fetchWeatherData(
  latitude: 49.2827,
  longitude: -123.1207,
  models: [.ecmwfIfs025, .iconSeamless]
)

// Access hourly data
for hourly in response.hourly {
  if let data = hourly[.ecmwfIfs025] {
    print("Time: \(hourly.time)")
    print("Temperature: \(data.temperature ?? 0)°C")
    print("Wind Speed: \(data.windSpeed ?? 0) kn")
  }
}
```

### Selecting Data Types

You can request specific data types to reduce response size:

```swift
// Temperature only
let tempResponse = try await client.fetchWeatherData(
  latitude: 40.7128,
  longitude: -74.0060,
  models: [.gfsSeamless],
  dataTypes: .temperature
)

// Wind only
let windResponse = try await client.fetchWeatherData(
  latitude: 40.7128,
  longitude: -74.0060,
  models: [.gfsSeamless],
  dataTypes: .wind
)

// All data types (default)
let allResponse = try await client.fetchWeatherData(
  latitude: 40.7128,
  longitude: -74.0060,
  models: [.gfsSeamless],
  dataTypes: .all  // .wind, .precipitation, .temperature
)
```

### Checking Model Availability

Some models only cover specific regions:

```swift
// Check if a model covers a location
let isAvailable = WeatherModel.hrrr.isAvailable(latitude: 40.7, longitude: -74.0)

// Get all available models for a location
let models = WeatherModel.availableModels(latitude: 40.7, longitude: -74.0)
```

### Wind Speed Units

```swift
let response = try await client.fetchWeatherData(
  latitude: 49.2827,
  longitude: -123.1207,
  models: [.ecmwfIfs025],
  windSpeedUnit: .kmh  // .knots, .mph, .ms, .kmh
)
```

## Supported Weather Models

| Model | Coverage | Description |
|-------|----------|-------------|
| ECMWF IFS025 | Global | European Centre for Medium-Range Weather Forecasts |
| ECMWF AIFS025 | Global | ECMWF AI-based model |
| ICON Seamless | Global | German Weather Service |
| GFS Seamless | Global | US Global Forecast System |
| HRRR | CONUS | High-Resolution Rapid Refresh (US only) |
| NBM | CONUS | National Blend of Models (US only) |
| GEM Global | Global | Canadian Global Environmental Multiscale |
| GEM Regional | North America | Canadian Regional model |
| GEM HRDPS | Canada/Northern US | Canadian High Resolution |

## Available Data

### WeatherModelData Properties

| Property | Type | Description |
|----------|------|-------------|
| `temperature` | `Double?` | 2-meter air temperature |
| `temperatureUnit` | `String?` | Temperature unit (e.g., "°C") |
| `windSpeed` | `Double?` | 10-meter wind speed |
| `windDirection` | `Int?` | Wind direction in degrees |
| `windGusts` | `Double?` | Wind gust speed |
| `precipitation` | `Double?` | Total precipitation |
| `rain` | `Double?` | Rain amount |
| `showers` | `Double?` | Shower amount |
| `snowfall` | `Double?` | Snowfall amount |
| `precipitationProbability` | `Int?` | Precipitation probability (%) |
| `weatherCode` | `Int?` | WMO weather condition code |

## License

MIT License
