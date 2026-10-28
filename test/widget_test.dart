import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/models/habit.dart';
import 'package:orbit/widgets/habit_item_card.dart';

Habit _habit({
  required HabitRepeatUnit unit,
  int every = 1,
  List<int> weekdays = const [],
}) {
  return Habit(
    id: 'card-test',
    title: 'Test habit',
    category: 'Health',
    iconCodePoint: Icons.favorite_rounded.codePoint,
    colorValue: 0xFF10B981,
    targetCount: 1,
    unit: 'times',
    createdAt: DateTime(2026, 1, 5),
    repeatUnit: unit,
    repeatEvery: every,
    repeatWeekdays: weekdays,
  );
}

void main() {
  testWidgets('daily habit card keeps the compact layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitItemCard(
            habit: _habit(unit: HabitRepeatUnit.days),
            onToggle: () {},
          ),
        ),
      ),
    );

    expect(find.text('Test habit'), findsOneWidget);
    expect(find.text('0/1 times'), findsOneWidget);
    expect(find.byIcon(Icons.event_repeat_rounded), findsNothing);
  });

  testWidgets('off-day card is read-only and shows the schedule', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HabitItemCard(
            habit: _habit(
              unit: HabitRepeatUnit.weeks,
              every: 2,
              weekdays: const [DateTime.tuesday],
            ),
            isOffDay: true,
            onToggle: () {},
          ),
        ),
      ),
    );

    expect(find.text('Test habit'), findsOneWidget);
    expect(find.textContaining('Every 2 weeks'), findsOneWidget);
    expect(find.byIcon(Icons.nights_stay_rounded), findsOneWidget);
  });
}
