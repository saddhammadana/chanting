import 'package:chanting/features/prayer_list/day_part.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 9, 27, hour, minute);

  test('each part of the day starts on its hour and ends before the next', () {
    expect(DayPart.of(at(4, 59)), DayPart.night);
    expect(DayPart.of(at(5)), DayPart.morning);
    expect(DayPart.of(at(10, 59)), DayPart.morning);
    expect(DayPart.of(at(11)), DayPart.midday);
    expect(DayPart.of(at(15, 59)), DayPart.midday);
    expect(DayPart.of(at(16)), DayPart.evening);
    expect(DayPart.of(at(18, 59)), DayPart.evening);
    expect(DayPart.of(at(19)), DayPart.night);
    expect(DayPart.of(at(0)), DayPart.night);
  });

  test('the service on offer is morning until 16:00, then evening', () {
    String service(int hour, [int minute = 0]) =>
        DayPart.of(at(hour, minute)).serviceSectionId;

    expect(service(5), 'tham-wat-chao');
    expect(service(15, 59), 'tham-wat-chao');
    expect(service(16), 'tham-wat-yen');
    expect(service(23), 'tham-wat-yen');
    expect(service(4, 59), 'tham-wat-yen');
  });
}
