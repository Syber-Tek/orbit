# Orbit - Project Coding Guidelines & Rules

## 1. Project Architecture (Layer-First)
The project strictly follows a **Layer-First** architecture:
* `lib/models/`: Data models and entity classes (immutable, serialization).
* `lib/screens/`: High-level page/screen views.
* `lib/widgets/`: Reusable, modular UI components.
* `lib/services/`: Backend API calls, network clients, database services, and external integrations.
* `lib/utils/`: Global constants, helper utilities, formatting functions, and theme configurations.

---

## 2. State Management (Riverpod)
* **Framework:** Riverpod.
* **Separation of Concerns:** Keep business logic, network orchestration, and mutable state inside Notifiers/Providers. Keep screen and widget trees strictly declarative.
* **Consumers:** Use `ConsumerWidget` or `ConsumerStatefulWidget` for widgets that consume Riverpod state. Avoid rebuilding parent trees when only a subwidget requires updates (use `ref.watch` selectively or `Consumer`).
* **Side Effects:** Trigger navigation and side effects in callbacks or listeners (`ref.listen`), never directly inside the `build` method.

---

## 3. UI, Styling & Theming
* **Theming:** Centralize colors, typography, and component styling inside `ThemeData` (`Material 3`). Use `Theme.of(context)` and `ColorScheme` instead of hardcoded hex values.
* **Icons & Assets:**
  * Use `iconly_plus` for system/app icons.
  * Use `flutter_svg` (`SvgPicture.asset` / `SvgPicture.network`) for SVG illustrations.
* **Layout Composition:** Prefer Flutter's standard widget composition (`Padding`, `SizedBox`, `Row`, `Column`, `Flex`) over external utility wrapper libraries.

---

## 4. Code Quality & Performance
* **Const Optimization:** Always use `const` constructors wherever parameters are compile-time constants.
* **Widget Decomposition:** Break large `build` methods into separate, reusable stateless/stateful widget classes rather than huge monolithic methods.
* **Minimal Impact:** Prioritize simple, effective additions and bug fixes over large refactors or modifying working code unnecessarily.
* **Error & Feedback Handling:** Use the existing app toast/snack notification pattern consistently; do not duplicate notification containers.

---

## 5. Core Modules & Feature Scope
Orbit is an all-in-one habit and productivity tracker:
* **Habits & Streaks:** Daily check-ins, routine scheduling, streak tracking, and habit analytics.
* **Alarms & Reminders/Todo:** Timed alarms, local notification reminders, task management with priorities.
* **Screen Time Management:** Digital wellbeing, focus sessions, app timers, and screen time insights.
* **Budget & Ledger:** Expense tracking, budget ceilings, categorical spending breakdown, and income ledger.
* **Notes:** Quick-capture scratchpad and rich-text notes linked to habits or tasks.

---

## 6. Git Branch Workflow
* `main`: Production/stable branch.
* `feature/habits-streaks`: Habit tracking and streak system.
* `feature/alarms-reminders`: Alarms, notifications, reminders, and todos.
* `feature/screen-time`: Screen time monitoring, focus modes, and timers.
* `feature/budget-ledger`: Budgets, ledger, and expense logging.
* `feature/notes`: Notes creation and document management.
