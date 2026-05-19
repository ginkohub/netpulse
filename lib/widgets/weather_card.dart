import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/weather_service.dart';
import 'base_card.dart';

class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherProvider>().fetchWeather();
    });
  }

  Color _getWeatherColor(WeatherData? data) {
    if (data == null) return Colors.grey;
    final desc = data.weatherDescription.toLowerCase();
    if (desc.contains('clear') || desc.contains('sun')) return Colors.orangeAccent;
    if (desc.contains('cloud')) return Colors.blueGrey;
    if (desc.contains('rain') || desc.contains('drizzle')) return Colors.lightBlueAccent;
    if (desc.contains('storm') || desc.contains('thunder')) return Colors.purpleAccent;
    if (desc.contains('snow')) return Colors.cyanAccent;
    if (desc.contains('fog') || desc.contains('mist')) return Colors.grey;
    return Colors.blueAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WeatherProvider>(
      builder: (context, provider, child) {
        final data = provider.data;
        final isLoading = provider.isLoading;
        final weatherColor = _getWeatherColor(data);

        return BaseCard(
          leading: Icon(
            data?.weatherIcon ?? Icons.wb_cloudy_outlined,
            color: weatherColor,
            size: 24,
          ),
          title: data?.locationName ?? 'Weather',
          subtitle: isLoading
              ? 'Loading...'
              : (data != null ? data.weatherDescription : 'No data'),
          subtitleColor: weatherColor.withAlpha(200),
          trailing: _buildTrailing(isLoading, data, weatherColor),
          children: data != null && data.daily.isNotEmpty
              ? [
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 36,
                        dataRowMinHeight: 32,
                        dataRowMaxHeight: 32,
                        columnSpacing: 16,
                        horizontalMargin: 12,
                        columns: const [
                          DataColumn(label: Text('', style: TextStyle(fontSize: 11))),
                          DataColumn(label: Text('Day', style: TextStyle(fontSize: 11, color: Colors.grey))),
                          DataColumn(label: Text('Min', style: TextStyle(fontSize: 11, color: Colors.grey)), numeric: true),
                          DataColumn(label: Text('Max', style: TextStyle(fontSize: 11, color: Colors.grey)), numeric: true),
                          DataColumn(label: Text('Condition', style: TextStyle(fontSize: 11, color: Colors.grey))),
                        ],
                        rows: data.daily.map((day) => DataRow(
                          cells: [
                            DataCell(Icon(day.weatherIcon, size: 24, color: weatherColor)),
                            DataCell(Text(day.dayName, style: const TextStyle(fontSize: 12, color: Colors.white))),
                            DataCell(Text('${day.minTemp.round()}°', style: const TextStyle(fontSize: 11, color: Colors.grey))),
                            DataCell(Text('${day.maxTemp.round()}°', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
                            DataCell(Text(day.weatherDescription, style: const TextStyle(fontSize: 10, color: Colors.grey))),
                          ],
                        )).toList(),
                      ),
                    ),
                  ),
                ]
              : null,
        );
      },
    );
  }

  Widget _buildTrailing(bool isLoading, WeatherData? data, Color weatherColor) {
    if (isLoading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(Colors.white70),
        ),
      );
    }

    if (data == null) {
      return Icon(Icons.swipe_right, size: 18, color: Colors.white.withAlpha(100));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [weatherColor.withAlpha(40), weatherColor.withAlpha(20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: weatherColor.withAlpha(60)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${data.temperature.round()}°',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.water_drop, size: 8, color: Colors.cyanAccent),
                  const SizedBox(width: 2),
                  Text(
                    '${data.humidity}%',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueGrey.withAlpha(40), Colors.blueGrey.withAlpha(20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blueGrey.withAlpha(60)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${data.windSpeed.round()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.air, size: 8, color: Colors.lightBlueAccent),
                  const SizedBox(width: 2),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.lightBlueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}