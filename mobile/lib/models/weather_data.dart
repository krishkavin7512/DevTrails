class WeatherReading {
  final double temperature;
  final double feelsLike;
  final double humidity;
  final double rainfall;
  final double windSpeed;
  final double aqi;
  final double pm25;
  final double pm10;
  final String weatherCondition;
  final String description;

  const WeatherReading({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.weatherCondition,
    required this.description,
  });

  factory WeatherReading.fromJson(Map<String, dynamic> json) =>
      WeatherReading(
        temperature: (json['temperature'] ?? 0).toDouble(),
        feelsLike: (json['feelsLike'] ?? 0).toDouble(),
        humidity: (json['humidity'] ?? 0).toDouble(),
        rainfall: (json['rainfall'] ?? 0).toDouble(),
        windSpeed: (json['windSpeed'] ?? 0).toDouble(),
        aqi: (json['aqi'] ?? 0).toDouble(),
        pm25: (json['pm25'] ?? 0).toDouble(),
        pm10: (json['pm10'] ?? 0).toDouble(),
        weatherCondition: json['weatherCondition'] ?? 'Clear',
        description: json['description'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'rainfall': rainfall,
        'windSpeed': windSpeed,
        'aqi': aqi,
        'pm25': pm25,
        'pm10': pm10,
        'weatherCondition': weatherCondition,
        'description': description,
      };
}

class WeatherData {
  final String id;
  final String city;
  final String pincode;
  final String dataType; // Weather | AQI | Flood | Social
  final WeatherReading data;
  final bool isDisruptionActive;
  final String disruptionSeverity; // None | Mild | Moderate | Severe | Extreme
  final DateTime fetchedAt;
  final String source;
  final DateTime createdAt;

  const WeatherData({
    required this.id,
    required this.city,
    required this.pincode,
    required this.dataType,
    required this.data,
    required this.isDisruptionActive,
    required this.disruptionSeverity,
    required this.fetchedAt,
    required this.source,
    required this.createdAt,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return WeatherData(
      id: json['_id'] ?? json['id'] ?? '',
      city: json['city'] ?? '',
      pincode: json['pincode'] ?? '',
      dataType: json['dataType'] ?? 'Weather',
      data: WeatherReading.fromJson(
          (json['data'] as Map<String, dynamic>?) ?? {}),
      isDisruptionActive: json['isDisruptionActive'] ?? false,
      disruptionSeverity: json['disruptionSeverity'] ?? 'None',
      fetchedAt: DateTime.tryParse(json['fetchedAt'] ?? '') ?? now,
      source: json['source'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? now,
    );
  }

  Map<String, dynamic> toJson() => {
        'city': city,
        'pincode': pincode,
        'dataType': dataType,
        'data': data.toJson(),
        'isDisruptionActive': isDisruptionActive,
        'disruptionSeverity': disruptionSeverity,
        'source': source,
      };

  /// Human-readable status for the dashboard weather card
  String get statusSummary {
    if (!isDisruptionActive) return 'All Clear';
    if (data.rainfall > 50) return 'Heavy Rain';
    if (data.temperature > 42) return 'Extreme Heat';
    if (data.aqi > 200) return 'Severe AQI';
    if (data.aqi > 150) return 'Poor Air Quality';
    return disruptionSeverity;
  }

  bool get isHazardous => isDisruptionActive && disruptionSeverity != 'Mild';
}
