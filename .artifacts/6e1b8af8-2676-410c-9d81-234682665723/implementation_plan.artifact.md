# Implementation Plan - Refactor Payroll Report Screen (Tabbed System)

Refactor the `PayrollReportScreen` to include a tab-based system (Daily Register, Employeewise, etc.) with dynamic filters, stats cards, and an initial empty state that matches the React implementation.

## User Review Required

> [!IMPORTANT]
> - Five tabs: **Daily Register**, **Employeewise**, **Monthly Attendance**, **Salary Sheet**, and **Salary Slip**.
> - Data will only appear after the user clicks "Refresh" or changes filters, starting with an "Apply filters" prompt.
> - The **Daily Register** tab will support both a detailed view and a summarized view (grouped by employee).

## Proposed Changes

### [Providers]

#### [MODIFY] [payroll_report_provider.dart](file:///D:/Hims/Himsapp/lib/providers/reports/payroll_report_provider.dart)
- Add `activeTab` (enum or string).
- Add `isFilterApplied` boolean.
- Initialize `dateFrom` and `dateTo` to today's date.
- Update `hasActiveFilters` to match React's logic (changed from defaults).
- Add `resetTabState()` to clear data when switching tabs.
- Ensure `fetchReport` correctly populates `attendanceRows` and sets `isFilterApplied = true`.

### [UI Components]

#### [MODIFY] [payroll_report_screen.dart](file:///D:/Hims/Himsapp/lib/screens/reports/payroll_report_screen.dart)
- **Header**: Title, Clock Badge, and a horizontal scrollable tab bar (Daily Register, Employeewise, etc.).
- **Dynamic Filter Section**:
    - **Daily Register**: Search, Date Range, Dept, Employee, Duty Shift, Sort.
    - **Employeewise**: (To be implemented based on React logic).
- **Dynamic Stats Section**:
    - **Daily Register**: Cards for Total Records, Employees, Departments, Shifts.
- **Table Section**:
    - Show "Apply filters to load report" if `!isFilterApplied`.
    - Handle **Daily Register** columns:
        - Detailed: Date, Time In, Time Out, Emp ID, Employee, Dept, Shift, Machine Code.
        - Summarized: Employee, Emp ID, Dept, Shift, Records.
- **Styling**: Remove bold text from data rows for a cleaner look.

## Verification Plan

### Automated Tests
- N/A

### Manual Verification
1. Open Payroll Report screen.
2. Verify 5 tabs appear at the top.
3. Verify table shows "Apply filters or search to load report" on entry.
4. Click Refresh/Apply filter and verify **Daily Register** data loads.
5. Toggle **Summarize** and verify table columns and grouping change correctly.
6. Verify Stats cards accurately count records/employees/etc.
