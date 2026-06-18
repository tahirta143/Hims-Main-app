import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../custum widgets/drawer/base_scaffold.dart';
import '../../custum widgets/search/global_search_overlay.dart';
import '../../providers/emergency_treatment_provider/emergency_provider.dart';
import '../../providers/opd/opd_reciepts/opd_reciepts.dart';
import '../../custum widgets/animations/animations.dart';

class EmergencyTreatmentScreen extends StatefulWidget {
  final bool useScaffold;
  const EmergencyTreatmentScreen({super.key, this.useScaffold = true});
  @override
  State<EmergencyTreatmentScreen> createState() => _EmergencyTreatmentScreenState();
}

class _EmergencyTreatmentScreenState extends State<EmergencyTreatmentScreen>
    with SingleTickerProviderStateMixin {

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const Color primary   = Color(0xFF00B5AD);
  static const Color danger    = Color(0xFFE53935);
  static const Color bgColor   = Color(0xFFF5F6FA);
  static const Color cardColor = Colors.white;

  late double _sw, _sh, _tp, _bp;
  bool get _wide => _sw >= 720;

  double get _fs   => _sw < 360 ? 11.5 : 13.0;
  double get _fsS  => _sw < 360 ?  9.5 : 11.0;
  double get _fsXS => _sw < 360 ?  8.0 :  9.5;
  double get _fsL  => _sw < 360 ? 14.0 : 16.5;
  double get _pad  => _sw * 0.04;
  double get _sp   => _sw * 0.025;
  double get _r    => _sw * 0.028;

  final _mrCtrl       = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _ageCtrl      = TextEditingController();
  final _genderCtrl   = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _moCtrl       = TextEditingController();
  final _bedCtrl      = TextEditingController();
  final _admCtrl      = TextEditingController(text: 'Auto-filled from Emergency Receipt');
  final _pulseCtrl    = TextEditingController();
  final _tempCtrl     = TextEditingController();
  final _bpCtrl       = TextEditingController();
  final _respCtrl     = TextEditingController();
  final _spo2Ctrl     = TextEditingController();
  final _weightCtrl   = TextEditingController();
  final _heightCtrl   = TextEditingController();
  final _complainCtrl = TextEditingController();
  final _notesCtrl    = TextEditingController();
  final _mrFocusNode   = FocusNode();
  final _invSearchCtrl = TextEditingController();
  final _medSearchCtrl = TextEditingController();

  bool _patientFound = false;
  int? _existingRecordId; // set when existing treatment loaded from API

  late TabController _rightTab;
  String _invType = 'Lab';

  String _disOpt     = 'Discharged';
  bool   _discharged = false;

  // ── Dropdown service state ──
  EmergencyService? _selectedDropdownService;

  // ── Hourly service time tracking: serviceId -> {startTime, endTime} ──
  final Map<String, Map<String, DateTime>> _hourlyServiceTimes = {};

  @override
  void initState() {
    super.initState();
    _rightTab = TabController(length: 2, vsync: this);
    _mrFocusNode.addListener(() {
      if (!_mrFocusNode.hasFocus) {
        _onMrTyped(_mrCtrl.text, Provider.of<EmergencyProvider>(context, listen: false));
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<EmergencyProvider>(context, listen: false)
          .refreshAll();
    });
  }

  /// Sync newly admitted OPD patients into the emergency queue
  void _syncOpdPatients() {
    final opdProv = Provider.of<OpdProvider>(context, listen: false);
    final emProv  = Provider.of<EmergencyProvider>(context, listen: false);
    for (final p in opdProv.admittedEmergencyPatients) {
      emProv.addPatientFromOpd(p);
    }
  }

  @override
  void dispose() {
    _rightTab.dispose();
    for (final c in [
      _mrCtrl,_nameCtrl,_ageCtrl,_genderCtrl,_phoneCtrl,_addressCtrl,
      _moCtrl,_bedCtrl,_admCtrl,_pulseCtrl,_tempCtrl,_bpCtrl,
      _respCtrl,_spo2Ctrl,_weightCtrl,_heightCtrl,_complainCtrl,_notesCtrl,
      _invSearchCtrl, _medSearchCtrl,
    ]) c.dispose();
    _mrFocusNode.dispose();
    super.dispose();
  }

  // ── MR AUTO-FORMAT + LOOKUP ──
  void _onMrTyped(String raw, EmergencyProvider prov) async {
    final formatted = EmergencyProvider.formatMr(raw);
    if (_mrCtrl.text != formatted) {
      _mrCtrl.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    if (formatted.isEmpty) { _resetPatient(); return; }

    // First check in-memory queue for quick fill
    final p = prov.lookupPatient(formatted);
    if (p != null) {
      _fillPatient(p);
    } else {
      // If not in queue, fetch full patient info from MR API
      final res = await prov.fetchPatientInfoByMR(formatted);
      if (res.success && res.patient != null) {
        setState(() {
          _patientFound = true;
          _nameCtrl.text = res.patient!.patientName;
          _ageCtrl.text = (res.patient!.age ?? '').toString();
          _genderCtrl.text = res.patient!.gender;
          _phoneCtrl.text = res.patient!.phoneNumber;
          _addressCtrl.text = res.patient!.address ?? '';
        });

        // Also fetch latest emergency receipt for metadata (admitted since, etc.)
        final receipt = await prov.fetchLatestEmergencyReceipt(formatted);
        if (receipt != null) {
          setState(() {
            _admCtrl.text = '${receipt.date} ${receipt.time ?? ''}'.trim();
          });
        }
      } else if (_patientFound) {
        _resetPatient();
      }
    }

    // Then call API to load existing treatment record (vitals, notes, etc.)
    if (formatted.isNotEmpty) {
      _loadExistingTreatment(formatted, prov);
    }
  }

  Future<void> _loadExistingTreatment(
      String mrNo, EmergencyProvider prov) async {
    final rec = await prov.fetchExistingTreatment(mrNo);
    if (rec == null) {
      setState(() => _existingRecordId = null);
      return;
    }
    // Update state: patient fields (if not already filled)
    setState(() {
      _existingRecordId = rec.srlNo;
      _patientFound = true;
      if (_nameCtrl.text.isEmpty) _nameCtrl.text = rec.patientName;
      if (_ageCtrl.text.isEmpty) _ageCtrl.text = rec.patientAge;
      if (_genderCtrl.text.isEmpty) _genderCtrl.text = rec.patientGender;
      if (_phoneCtrl.text.isEmpty) _phoneCtrl.text = rec.phoneNumber;
      if (_addressCtrl.text.isEmpty) _addressCtrl.text = rec.address;
      // Clinical fields
      _moCtrl.text    = rec.mo;
      _bedCtrl.text   = rec.bed;
      _pulseCtrl.text = rec.pulse;
      _tempCtrl.text  = rec.temp;
      _bpCtrl.text    = rec.bp;
      _respCtrl.text  = rec.respRate;
      _spo2Ctrl.text  = rec.spo2;
      _weightCtrl.text = rec.weight;
      _heightCtrl.text = rec.height;
      _complainCtrl.text = rec.complaint;
      _notesCtrl.text    = rec.moNotes;
      _disOpt = _mapOutcome(rec.outcome);
      // Admitted since
      if (rec.admittedSince != null && rec.admittedSince!.isNotEmpty) {
        try {
          final dt = DateTime.parse(rec.admittedSince!);
          _admCtrl.text = _fmtDt(dt);
        } catch (_) {
          _admCtrl.text = rec.admittedSince!;
        }
      }
    });
    // Auto-select services from existing record
    if (rec.selectedServices.isNotEmpty) {
      prov.clearAll();
      for (final svcName in rec.selectedServices) {
        final match = prov.emergencyServices.where(
          (s) => s.name.toLowerCase() == svcName.toLowerCase(),
        );
        for (final m in match) {
          if (!prov.isServiceSelected(m.id)) prov.toggleService(m);
        }
      }
    }
    // Auto-populate investigations and medicines from the record
    prov.setAddedInvestigations(rec.investigations);
    prov.setPrescribedMedicines(rec.medicines);
  }

  String _mapOutcome(String? outcome) {
    if (outcome == null || outcome.isEmpty) return 'Discharged';
    switch (outcome) {
      case 'after_treatment':        return 'Discharged';
      case 'refer_admission':        return 'Admitted to Ward';
      case 'refer_other_hospital':   return 'Referred';
      case 'patient_expired':        return 'Expired';
      default: return outcome;
    }
  }

  String _outcomeKey(String label) {
    return label;
  }

  void _fillPatient(EmergencyPatient p) {
    setState(() {
      _patientFound     = true;
      _mrCtrl.text      = p.mrNo;
      _nameCtrl.text    = p.name;
      _ageCtrl.text     = p.age;
      _genderCtrl.text  = p.gender;
      _phoneCtrl.text   = p.phone;
      _addressCtrl.text = p.address;
      _admCtrl.text     = _fmtDt(p.admittedSince);
    });

    // Auto-select emergency services from the patient's admission
    if (p.emergencyServices.isNotEmpty) {
      final emProv = Provider.of<EmergencyProvider>(context, listen: false);
      // Clear existing selections
      emProv.clearAll();
      // Auto-add services that match
      for (final svcName in p.emergencyServices) {
        final match = emProv.emergencyServices.where(
              (s) => s.name.toLowerCase().contains(svcName.toLowerCase()) ||
              svcName.toLowerCase().contains(s.name.toLowerCase()),
        ).toList();
        for (final m in match) {
          if (!emProv.isServiceSelected(m.id)) {
            emProv.toggleService(m);
          }
        }
      }
    }
  }

  void _resetPatient() {
    setState(() { _patientFound = false; });
    _nameCtrl.clear(); _ageCtrl.clear(); _genderCtrl.clear();
    _phoneCtrl.clear(); _addressCtrl.clear();
    _admCtrl.text = 'Auto-filled from Emergency Receipt';
  }

  String _fmtDt(DateTime d) =>
      '${_d2(d.day)}/${_d2(d.month)}/${d.year}  ${_d2(d.hour)}:${_d2(d.minute)}';

  String _d2(int n) => n.toString().padLeft(2, '0');

  void _clearAll(EmergencyProvider prov) {
    for (final c in [
      _mrCtrl,_nameCtrl,_ageCtrl,_genderCtrl,_phoneCtrl,_addressCtrl,
      _moCtrl,_bedCtrl,_pulseCtrl,_tempCtrl,_bpCtrl,_respCtrl,
      _spo2Ctrl,_weightCtrl,_heightCtrl,_complainCtrl,_notesCtrl,
    ]) c.clear();
    _admCtrl.text = 'Auto-filled from Emergency Receipt';
    setState(() {
      _patientFound = false;
      _existingRecordId = null;
      _disOpt = 'After Treatment';
      _discharged = false;
      _selectedDropdownService = null;
      _hourlyServiceTimes.clear();
    });
    prov.clearAll();
  }

  Future<void> _handleGenerateBill(EmergencyProvider prov) async {
    if (_mrCtrl.text.isEmpty) {
      _snack('Please select a patient from the queue first', err: true);
      return;
    }
    if (prov.selectedServices.isEmpty) {
      _snack('Please select at least one service', err: true);
      return;
    }

    // 1. Fetch current shift
    final shiftResult = await prov.fetchCurrentShift();
    if (!shiftResult.success || shiftResult.shift == null) {
      _snack(shiftResult.message ?? 'No active shift found. Please open a shift first.', err: true);
      return;
    }

    final shift = shiftResult.shift!;

    // 2. Prepare payload exactly like React
    final payload = {
      'patient_name': _nameCtrl.text,
      'shift_date': shift.shiftDate,
      'shift_type': shift.shiftType,
      'shift_id': shift.shiftId,
      'items': prov.selectedServices.map((s) => {
        'service_head': s.name,
        'amount': s.price,
      }).toList(),
    };

    // 3. Create bill
    final result = await prov.createBill(payload);
    if (result.success) {
      _snack('Bill generated successfully! ${result.message ?? ""}');
      prov.clearAll(); // Clears selected services
      setState(() {
        _selectedDropdownService = null;
      });
    } else {
      _snack(result.message ?? 'Failed to generate bill', err: true);
    }
  }

  Future<void> _printDischargeSlip(
    EmergencyProvider prov,
    Map<String, dynamic> payload,
    List<Map<String, dynamic>> billedServices,
    double billedTotal,
  ) async {
    final doc = pw.Document();
    final printDateTime = DateTime.now().toString().substring(0, 16);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'HIMS HOSPITAL',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'EMERGENCY DISCHARGE SLIP',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('MR #: ${payload['patient_mr_number'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Patient: ${payload['patient_name'] ?? ''}'),
                        pw.Text('Age/Gender: ${payload['patient_age'] ?? ''} / ${payload['patient_gender'] ?? ''}'),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Date/Time: $printDateTime'),
                        pw.Text('Bed: ${payload['bed'] ?? ''}'),
                        pw.Text('Outcome: ${payload['outcome'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text('VITALS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('B.P: ${payload['bp'] ?? ''}   Temp: ${payload['temp'] ?? ''}   Pulse: ${payload['pulse'] ?? ''}   SPO2: ${payload['spo2'] ?? ''}   Weight: ${payload['weight'] ?? ''}   Height: ${payload['height'] ?? ''}'),
                pw.SizedBox(height: 10),
                pw.Text('CHIEF COMPLAINTS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(payload['complaint'] ?? '—'),
                pw.SizedBox(height: 10),
                pw.Text('MO NOTES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(payload['mo_notes'] ?? '—'),
                pw.SizedBox(height: 15),
                if (billedServices.isNotEmpty) ...[
                  pw.Text('SERVICES & BILLING', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Service Head', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        ],
                      ),
                      ...billedServices.map((item) => pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(item['service_name'] ?? '')),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs ${(item['amount'] as double).toStringAsFixed(0)}', textAlign: pw.TextAlign.right)),
                        ],
                      )),
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rs ${billedTotal.toStringAsFixed(0)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 15),
                ],
                if (prov.addedInvestigations.isNotEmpty) ...[
                  pw.Text('PRESCRIBED INVESTIGATIONS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  ...prov.addedInvestigations.map((inv) => pw.Bullet(text: '[${inv.type}] ${inv.name}')),
                  pw.SizedBox(height: 15),
                ],
                if (prov.prescribedMedicines.isNotEmpty) ...[
                  pw.Text('DISCHARGE RX (MEDICINES)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  ...prov.prescribedMedicines.map((med) => pw.Bullet(text: '${med.name}  (${med.plan} for ${med.days} days)')),
                  pw.SizedBox(height: 15),
                ],
                pw.Spacer(),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Prepared By: ${payload['mo'] ?? ''}'),
                    pw.Text('Authorized Signature: _____________________'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'discharge_slip_${payload['patient_mr_number']}.pdf',
    );
  }

  Future<void> _saveAndPrint(EmergencyProvider prov) async {
    if (_nameCtrl.text.trim().isEmpty) {
      _snack('Please fill patient name', err: true);
      return;
    }

    final servicesTotal = prov.servicesTotalPrice;
    final isBilled = (prov.currentRecord?.isBilled ?? false) &&
        servicesTotal > 0 &&
        servicesTotal == (prov.currentRecord?.servicesTotal ?? 0);

    if (_discharged && !isBilled && servicesTotal > 0) {
      _snack('Cannot discharge patient with pending bills. Please pay the bill at the OPD Receipt counter to proceed.', err: true);
      return;
    }

    final payload = {
      'patient_mr_number': _mrCtrl.text,
      'patient_name':  _nameCtrl.text,
      'patient_age':   _ageCtrl.text,
      'patient_gender':_genderCtrl.text,
      'phone_number':  _phoneCtrl.text,
      'address':       _addressCtrl.text,
      'mo':            _moCtrl.text,
      'bed':           _bedCtrl.text,
      'pulse':         _pulseCtrl.text,
      'temp':          _tempCtrl.text,
      'bp':            _bpCtrl.text,
      'resp_rate':     _respCtrl.text,
      'spo2':          _spo2Ctrl.text,
      'weight':        _weightCtrl.text,
      'height':        _heightCtrl.text,
      'complaint':     _complainCtrl.text,
      'mo_notes':      _notesCtrl.text,
      'outcome':       _outcomeKey(_disOpt),
      'discharge_patient': _discharged,
      'selected_services': prov.selectedServices.map((s) => s.name).toList(),
      'services_total': servicesTotal,
      'is_billed': isBilled,
      'investigations': prov.addedInvestigations.map((i) => i.toJson()).toList(),
      'medicines': prov.prescribedMedicines.map((m) => m.toJson()).toList(),
    };

    bool apiSuccess;
    String? apiMessage;

    if (_existingRecordId != null) {
      final result = await prov.updateToApi(_existingRecordId!, payload);
      apiSuccess = result.success;
      apiMessage = result.message;
    } else {
      final result = await prov.saveToApi(payload);
      apiSuccess = result.success;
      apiMessage = result.message;
      if (result.success && result.record != null) {
        setState(() => _existingRecordId = result.record!.srlNo);
      }
    }

    if (!apiSuccess) {
      _snack(apiMessage ?? 'Failed to save record', err: true);
      return;
    }

    // Also call local saveRecord to update queue state
    prov.saveRecord(
      mrNo: _mrCtrl.text, name: _nameCtrl.text, age: _ageCtrl.text,
      gender: _genderCtrl.text, phone: _phoneCtrl.text, address: _addressCtrl.text,
      mo: _moCtrl.text, bed: _bedCtrl.text,
      complaint: _complainCtrl.text, moNotes: _notesCtrl.text,
      dischargeOpt: _disOpt,
      services: prov.selectedServices.toList(),
      investigations: prov.addedInvestigations.toList(),
      medicines: prov.prescribedMedicines.toList(),
    );

    _snack('Record saved successfully');

    // Fetch billed services if discharged
    List<Map<String, dynamic>> printServiceRows = prov.selectedServices.map((s) => {'service_name': s.name, 'amount': s.price}).toList();
    double printServicesTotal = prov.servicesTotalPrice;
    
    if (_discharged) {
      try {
        String mysqlFrom = '';
        try {
          final parts = _admCtrl.text.split('  ');
          if (parts.length >= 2) {
            final dateParts = parts[0].split('/');
            final timeParts = parts[1].split(':');
            if (dateParts.length == 3 && timeParts.length >= 2) {
              final parsedDt = DateTime(
                int.parse(dateParts[2]),
                int.parse(dateParts[1]),
                int.parse(dateParts[0]),
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );
              mysqlFrom = parsedDt.toString().substring(0, 19);
            }
          }
        } catch (_) {}
        
        if (mysqlFrom.isEmpty) {
          mysqlFrom = DateTime.now().subtract(const Duration(hours: 1)).toString().substring(0, 19);
        }
        
        final mysqlTo = DateTime.now().toString().substring(0, 19);
        
        final billed = await prov.fetchBilledServices(
          patientName: _nameCtrl.text,
          from: mysqlFrom,
          to: mysqlTo,
        );
        if (billed.isNotEmpty) {
          printServiceRows = billed.map((b) => {
            'service_name': b['service_head']?.toString() ?? '',
            'amount': double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0,
          }).toList();
          printServicesTotal = printServiceRows.fold(0.0, (sum, item) => sum + (item['amount'] as double));
        }
      } catch (_) {}
    }

    // Call print
    await _printDischargeSlip(prov, payload, printServiceRows, printServicesTotal);

    _clearAll(prov);
    // Refresh queue after save
    prov.refreshAll();
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: err ? Colors.red.shade400 : primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.03)),
      margin: EdgeInsets.all(_pad),
    ));
  }

  // ════════════════════════════════════════
  //  HOURLY SERVICE TIME POPUP
  // ════════════════════════════════════════

  /// Shows a popup dialog to set start and end time for an hourly service.
  /// Returns [true] if user confirmed, [false]/[null] otherwise.
  Future<bool?> _showHourlyTimePopup(EmergencyService svc,
      {bool isEdit = false}) async {
    // Pre-fill start time from admitted since or current time
    DateTime startTime;
    DateTime endTime;

    final existing = _hourlyServiceTimes[svc.id];
    if (existing != null) {
      startTime = existing['start']!;
      endTime = existing['end']!;
    } else {
      // Try to parse admitted since
      try {
        if (_admCtrl.text.isNotEmpty &&
            _admCtrl.text != 'Auto-filled from Emergency Receipt') {
          final parts = _admCtrl.text.split('  ');
          if (parts.length >= 2) {
            final dateParts = parts[0].split('/');
            final timeParts = parts[1].split(':');
            if (dateParts.length == 3 && timeParts.length >= 2) {
              startTime = DateTime(
                int.parse(dateParts[2]),
                int.parse(dateParts[1]),
                int.parse(dateParts[0]),
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );
            } else {
              startTime = DateTime.now();
            }
          } else {
            startTime = DateTime.now();
          }
        } else {
          startTime = DateTime.now();
        }
      } catch (_) {
        startTime = DateTime.now();
      }
      endTime = DateTime.now();
    }

    // Local state inside the dialog
    DateTime tempStart = startTime;
    DateTime tempEnd = endTime;

    String formatDt(DateTime dt) => _fmtDt(dt);

    Future<void> pickDateTime(
        BuildContext ctx, bool isStart, StateSetter setDlgState) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: ctx,
        initialDate: isStart ? tempStart : tempEnd,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 1),
        builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF59E0B),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
      if (picked == null) return;
      final timePicked = await showTimePicker(
        context: ctx,
        initialTime: TimeOfDay.fromDateTime(isStart ? tempStart : tempEnd),
        builder: (ctx, child) => Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF59E0B),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        ),
      );
      if (timePicked == null) return;
      final result = DateTime(picked.year, picked.month, picked.day,
          timePicked.hour, timePicked.minute);
      setDlgState(() {
        if (isStart) {
          tempStart = result;
        } else {
          tempEnd = result;
        }
      });
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              left: _sw * 0.05,
              right: _sw * 0.05,
              top: _sh * 0.025,
              bottom: _sh * 0.035 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Drag handle ──
                Center(
                  child: Container(
                    width: _sw * 0.1,
                    height: 4,
                    margin: EdgeInsets.only(bottom: _sh * 0.018),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // ── Header ──
                Row(children: [
                  Container(
                    padding: EdgeInsets.all(_sw * 0.022),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.access_time_rounded,
                        color: Colors.amber.shade700, size: _sw * 0.055),
                  ),
                  SizedBox(width: _sw * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hourly Service',
                          style: TextStyle(
                              fontSize: _fsXS,
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4),
                        ),
                        Text(
                          svc.name,
                          style: TextStyle(
                              fontSize: _fsL,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: _sw * 0.025, vertical: _sh * 0.005),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(_sw * 0.03),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      'PKR ${svc.price.toStringAsFixed(0)}/hr',
                      style: TextStyle(
                          fontSize: _fsXS,
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),

                SizedBox(height: _sh * 0.025),
                Divider(color: Colors.grey.shade100),
                SizedBox(height: _sh * 0.018),

                // ── START TIME ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Start Time',
                        style: TextStyle(
                            fontSize: _fsS,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: () {
                        setDlgState(() {
                          tempStart = DateTime.now();
                        });
                      },
                      icon: const Icon(Icons.play_arrow_rounded, color: Colors.green, size: 16),
                      label: const Text('Start Now', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.green.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _sh * 0.008),
                GestureDetector(
                  onTap: () => pickDateTime(ctx, true, setDlgState),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: _sw * 0.04, vertical: _sh * 0.016),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(_sw * 0.03),
                      border: Border.all(color: Colors.green.shade200, width: 1.5),
                    ),
                    child: Row(children: [
                      Icon(Icons.play_circle_outline_rounded,
                          color: Colors.green.shade600, size: _sw * 0.055),
                      SizedBox(width: _sw * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Start',
                                style: TextStyle(
                                    fontSize: _fsXS,
                                    color: Colors.green.shade600,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              formatDt(tempStart),
                              style: TextStyle(
                                  fontSize: _fs,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_calendar_rounded,
                          color: Colors.green.shade400, size: _sw * 0.04),
                    ]),
                  ),
                ),

                SizedBox(height: _sh * 0.015),

                // ── END TIME ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('End Time',
                        style: TextStyle(
                            fontSize: _fsS,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: () {
                        setDlgState(() {
                          tempEnd = DateTime.now();
                        });
                      },
                      icon: const Icon(Icons.stop_rounded, color: Colors.red, size: 16),
                      label: const Text('End Now', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.red.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _sh * 0.008),
                GestureDetector(
                  onTap: () => pickDateTime(ctx, false, setDlgState),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: _sw * 0.04, vertical: _sh * 0.016),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(_sw * 0.03),
                      border: Border.all(color: Colors.red.shade200, width: 1.5),
                    ),
                    child: Row(children: [
                      Icon(Icons.stop_circle_outlined,
                          color: Colors.red.shade500, size: _sw * 0.055),
                      SizedBox(width: _sw * 0.03),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('End',
                                style: TextStyle(
                                    fontSize: _fsXS,
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w600)),
                            Text(
                              formatDt(tempEnd),
                              style: TextStyle(
                                  fontSize: _fs,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_calendar_rounded,
                          color: Colors.red.shade300, size: _sw * 0.04),
                    ]),
                  ),
                ),

                SizedBox(height: _sh * 0.012),

                // ── Duration indicator ──
                Builder(builder: (_) {
                  final diff = tempEnd.difference(tempStart);
                  final isValid = diff.inMinutes > 0;
                  final hrs = diff.inHours;
                  final mins = diff.inMinutes.remainder(60);
                  return Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: _sw * 0.04, vertical: _sh * 0.009),
                    decoration: BoxDecoration(
                      color: isValid
                          ? Colors.amber.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(_sw * 0.025),
                      border: Border.all(
                          color: isValid
                              ? Colors.amber.shade200
                              : Colors.red.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isValid ? Icons.timer_rounded : Icons.warning_amber_rounded,
                          color: isValid ? Colors.amber.shade700 : Colors.red.shade600,
                          size: _sw * 0.04,
                        ),
                        SizedBox(width: _sw * 0.02),
                        Text(
                          isValid
                              ? 'Duration: ${hrs > 0 ? "${hrs}h " : ""}${mins}m'
                              : 'End time must be after start time',
                          style: TextStyle(
                            fontSize: _fsS,
                            fontWeight: FontWeight.bold,
                            color: isValid
                                ? Colors.amber.shade800
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                SizedBox(height: _sh * 0.022),

                // ── Action Buttons ──
                Row(children: [
                  // Cancel button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding:
                            EdgeInsets.symmetric(vertical: _sh * 0.016),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_sw * 0.03)),
                      ),
                      child: Text('Cancel',
                          style: TextStyle(
                              fontSize: _fs, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  SizedBox(width: _sw * 0.03),
                  // Confirm button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final diff = tempEnd.difference(tempStart);
                        if (diff.inMinutes <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('End time must be after start time'),
                            backgroundColor: Colors.red.shade400,
                            behavior: SnackBarBehavior.floating,
                          ));
                          return;
                        }
                        setState(() {
                          _hourlyServiceTimes[svc.id] = {
                            'start': tempStart,
                            'end': tempEnd,
                          };
                        });
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade600,
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(vertical: _sh * 0.016),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_sw * 0.03)),
                      ),
                      icon: Icon(Icons.check_circle_rounded,
                          size: _sw * 0.045),
                      label: Text(
                        isEdit ? 'Update Time' : 'Set Time & Add',
                        style: TextStyle(
                            fontSize: _fs, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );

    return confirmed;
  }

  // ════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    _sw = mq.size.width; _sh = mq.size.height;
    _tp = mq.padding.top; _bp = mq.padding.bottom;

    // Sync OPD patients every build (catches new admissions)
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOpdPatients());

    return Consumer<EmergencyProvider>(
      builder: (_, prov, __) {
        final content = Column(children: [
          _header(prov),
          Expanded(child: _wide ? _wideLayout(prov) : _narrowLayout(prov)),
        ]);

        if (!widget.useScaffold) return content;

        return BaseScaffold(
          scaffoldKey: _scaffoldKey,
          title: 'Emergency Treatment',
          drawerIndex: 5,
          showAppBar: false,
          body: CustomPageTransition(
            child: content,
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════
  Widget _header(EmergencyProvider prov) {
    final now = DateTime.now();
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h   = now.hour;
    final h12 = h == 0 ? 12 : h > 12 ? h - 12 : h;
    final ampm = h < 12 ? 'AM' : 'PM';
    final dateStr = '${now.day} ${mo[now.month-1]} ${now.year}'
        '  ${_d2(h12)}:${_d2(now.minute)}:${_d2(now.second)} $ampm';

    // return Container(
    //
    //   decoration: BoxDecoration(
    //       color: Colors.red.shade50,
    //       borderRadius: BorderRadius.only(
    //         bottomLeft:Radius.circular(20),
    //         bottomRight:Radius.circular(20),
    //       )
    //   ),
    //   padding: EdgeInsets.only(
    //       top: _tp + _sh * 0.013, bottom: _sh * 0.013,
    //       left: _pad, right: _pad),
    //   child: Row(children: [
    //     GestureDetector(
    //       onTap: () { _scaffoldKey.currentState?.openDrawer(); },
    //       child: Container(
    //         padding: EdgeInsets.all(_sw * 0.022),
    //         decoration: BoxDecoration(
    //           color: danger.withOpacity(0.12),
    //           borderRadius: BorderRadius.circular(_sw * 0.022),
    //         ),
    //         child: Icon(Icons.menu_rounded, color: danger, size: _sw * 0.048),
    //       ),
    //     ),
    //     SizedBox(width: _sp * 0.7),
    //     Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    //       Text('Emergency Treatment',
    //           style: TextStyle(fontSize: _fsL, fontWeight: FontWeight.bold, color: Colors.black87),
    //           maxLines: 1, overflow: TextOverflow.ellipsis),
    //       // Text('Manage emergency patient treatments',
    //       //     style: TextStyle(fontSize: _fsS, color: Colors.grey.shade500)),
    //     ])),
    //     if (!_wide) ...[
    //       GestureDetector(
    //         onTap: () => _openSheet(prov),
    //         child: Container(
    //           margin: EdgeInsets.only(right: _sw * 0.018),
    //           padding: EdgeInsets.all(_sw * 0.02),
    //           decoration: BoxDecoration(
    //             color: primary.withOpacity(0.1),
    //             borderRadius: BorderRadius.circular(_sw * 0.02),
    //           ),
    //           child: Stack(clipBehavior: Clip.none, children: [
    //             Icon(Icons.people_alt_rounded, color: primary, size: _sw * 0.048),
    //             if (prov.queueCount > 0) Positioned(
    //               right: -_sw * 0.01, top: -_sw * 0.01,
    //               child: Container(
    //                 width: _sw * 0.03, height: _sw * 0.03,
    //                 decoration: const BoxDecoration(color: danger, shape: BoxShape.circle),
    //                 child: Center(child: Text('${prov.queueCount}',
    //                     style: TextStyle(color: Colors.white, fontSize: _sw * 0.016,
    //                         fontWeight: FontWeight.bold))),
    //               ),
    //             ),
    //           ]),
    //         ),
    //       ),
    //     ],
    //     Container(
    //       padding: EdgeInsets.symmetric(horizontal: _sw * 0.022, vertical: _sh * 0.007),
    //       decoration: BoxDecoration(
    //         color: const Color(0xFFF0F4F8),
    //         borderRadius: BorderRadius.circular(_sw * 0.022),
    //         border: Border.all(color: Colors.grey.shade200),
    //       ),
    //       child: Row(mainAxisSize: MainAxisSize.min, children: [
    //         Icon(Icons.access_time_rounded, color: Colors.grey.shade500, size: _sw * 0.032),
    //         SizedBox(width: _sw * 0.01),
    //         Text(dateStr, style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade600)),
    //       ]),
    //     ),
    //   ]),
    // );
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            // Color(0xFFD32F2F), // deep red
            // Color(0xFFE53935), // normal red
            Color(0xFFEF5350), // light red
            Color(0xFFEF5350), // light red
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.only(
        top: _tp + _sh * 0.015,
        bottom: _sh * 0.015,
        left: _pad,
        right: _pad,
      ),
      child: Row(
        children: [
          // ☰ MENU BUTTON
          GestureDetector(
             onTap: () {
               if (widget.useScaffold) {
                 _scaffoldKey.currentState?.openDrawer();
               } else {
                 Scaffold.of(context).openDrawer();
               }
             },
            child: Container(
              padding: EdgeInsets.all(_sw * 0.022),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(_sw * 0.025),
              ),
              child: Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: _sw * 0.05,
              ),
            ),
          ),

          SizedBox(width: _sp),

          // 🏥 TITLE + SUBTITLE
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Treatment',
                  style: TextStyle(
                    fontSize: _fsL,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2),
                // Text(
                //   'Manage emergency patients quickly',
                //   style: TextStyle(
                //     fontSize: _fsXS,
                //     color: Colors.white.withOpacity(0.85),
                //   ),
                // ),
              ],
            ),
          ),

          // 👥 QUEUE BUTTON (MOBILE)
          if (!_wide) ...[
            GestureDetector(
              onTap: () => _openPopup(prov),
              child: Container(
                margin: EdgeInsets.only(right: _sw * 0.02),
                padding: EdgeInsets.all(_sw * 0.02),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(_sw * 0.025),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.people_alt_rounded,
                        color: Colors.white, size: _sw * 0.05),

                    if (prov.queueCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${prov.queueCount}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _sw * 0.02,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],

          // 🔍 SEARCH BUTTON
          GestureDetector(
            onTap: () => showGlobalSearchOverlay(context),
            child: Container(
              margin: EdgeInsets.only(right: _sw * 0.02),
              padding: EdgeInsets.all(_sw * 0.02),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(_sw * 0.025),
              ),
              child: Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: _sw * 0.05,
              ),
            ),
          ),
        ],
      ),
    );

  }

  // ════════════════════════════════════════
  //  WIDE layout
  // ════════════════════════════════════════
  Widget _wideLayout(EmergencyProvider prov) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 64, child: _leftForm(prov)),
      SizedBox(width: _sw * 0.33, child: _rightPanel(prov)),
    ],
  );

  Widget _narrowLayout(EmergencyProvider prov) => _leftForm(prov);

  Widget _buildBodyTimeBox() {
    final now = DateTime.now();
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h   = now.hour;
    final h12 = h == 0 ? 12 : h > 12 ? h - 12 : h;
    final ampm = h < 12 ? 'AM' : 'PM';
    final dateStr = '${now.day} ${mo[now.month-1]} ${now.year}'
        '  ${_d2(h12)}:${_d2(now.minute)}:${_d2(now.second)} $ampm';

    return Container(
      margin: EdgeInsets.only(bottom: _sh * 0.014),
      child: _card(
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(_sw * 0.02),
              decoration: BoxDecoration(
                color: danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time_rounded,
                color: danger,
                size: _sw * 0.045,
              ),
            ),
            SizedBox(width: _sw * 0.03),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admission Date & Time',
                  style: TextStyle(
                    fontSize: _fsXS,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: _sh * 0.003),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: _fs,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  //  LEFT FORM
  // ════════════════════════════════════════
  Widget _leftForm(EmergencyProvider prov) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
              _pad, _sh * 0.012,
              _wide ? _pad * 0.5 : _pad,
              120),
          sliver: SliverList(delegate: SliverChildListDelegate([
            FadeInUp(delay: const Duration(milliseconds: 50), child: _buildBodyTimeBox()),
            FadeInUp(delay: const Duration(milliseconds: 100), child: _patientInfoCard(prov)),
            SizedBox(height: _sh * 0.014),
            FadeInUp(delay: const Duration(milliseconds: 200), child: _moCard()),
            SizedBox(height: _sh * 0.014),
            FadeInUp(delay: const Duration(milliseconds: 300), child: _vitalsCard()),
            SizedBox(height: _sh * 0.014),
            FadeInUp(delay: const Duration(milliseconds: 400), child: _servicesCard(prov)),
            SizedBox(height: _sh * 0.014),
            FadeInUp(delay: const Duration(milliseconds: 500), child: _notesCard()),
            SizedBox(height: _sh * 0.014),
            FadeInUp(delay: const Duration(milliseconds: 600), child: _dischargeCard()),
            SizedBox(height: _sh * 0.014),
            FadeInUp(delay: const Duration(milliseconds: 700), child: _bottomBtns(prov)),
          ])),
        ),
      ],
    );
  }

  // ──────────────────────────────────────
  //  1. PATIENT INFORMATION CARD
  // ──────────────────────────────────────
  Widget _patientInfoCard(EmergencyProvider prov) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.person_rounded, color: danger, size: _sw * 0.042),
        SizedBox(width: _sw * 0.018),
        Text('Patient Information',
            style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold, color: danger)),
        const Spacer(),
        Text('MR #', style: TextStyle(fontSize: _fsS, color: Colors.black54, fontWeight: FontWeight.w600)),
        SizedBox(width: _sw * 0.012),
        SizedBox(width: _sw * 0.26,
          child: TextField(
            controller: _mrCtrl,
            focusNode: _mrFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold, color: Colors.black87),
            decoration: _dec('Enter MR').copyWith(
              contentPadding: EdgeInsets.symmetric(horizontal: _sw * 0.025, vertical: _sh * 0.009),
              suffixIcon: _patientFound
                  ? Icon(Icons.check_circle_rounded, color: Colors.green, size: _sw * 0.038) : null,
            ),
            onChanged: (v) => _onMrTyped(v, prov),
            onSubmitted: (v) => _onMrTyped(v, prov),
          ),
        ),
        SizedBox(width: _sw * 0.012),
        GestureDetector(
          onTap: () => _onMrTyped(_mrCtrl.text, prov),
          child: Container(
            padding: EdgeInsets.all(_sw * 0.02),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(_sw * 0.02),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(Icons.search_rounded, color: Colors.grey.shade600, size: _sw * 0.04),
          ),
        ),
      ]),
      SizedBox(height: _sh * 0.013),
      Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
      SizedBox(height: _sh * 0.012),

      // ── Emergency Queue patient selector dropdown ──
      Consumer<EmergencyProvider>(builder: (_, p, __) {
        if (p.queue.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.people_alt_rounded, color: danger, size: _sw * 0.036),
            SizedBox(width: _sw * 0.012),
            Text('Select from Emergency Queue',
                style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w700, color: danger)),
          ]),
          SizedBox(height: _sh * 0.007),
          Container(
            padding: EdgeInsets.symmetric(horizontal: _sw * 0.025),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(_sw * 0.022),
              border: Border.all(color: danger.withOpacity(0.35)),
            ),
            child: DropdownButtonHideUnderline(
              child: Builder(
                builder: (context) {
                  final seen = <String>{};
                  final uniqueQueue = p.queue.where((patient) => seen.add(patient.mrNo)).toList();
                  final hasMr = uniqueQueue.any((patient) => patient.mrNo == _mrCtrl.text);
                  
                  return DropdownButton<String>(
                    isExpanded: true,
                    hint: Text('-- Select Emergency Patient --',
                        style: TextStyle(color: Colors.red.shade400, fontSize: _fs)),
                    value: _patientFound && hasMr ? _mrCtrl.text : null,
                    style: TextStyle(fontSize: _fs, color: Colors.black87),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: danger, size: _sw * 0.048),
                    dropdownColor: Colors.white,
                    items: uniqueQueue.map((patient) {
                      final diff = DateTime.now().difference(patient.admittedSince);
                      final since = diff.inMinutes < 60
                          ? '${diff.inMinutes}m ago'
                          : '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
                      return DropdownMenuItem<String>(
                        value: patient.mrNo,
                        child: Row(children: [
                          Container(
                            padding: EdgeInsets.all(_sw * 0.015),
                            decoration: BoxDecoration(
                              color: danger.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.emergency_rounded, color: danger, size: _sw * 0.032),
                          ),
                          SizedBox(width: _sw * 0.018),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(patient.name,
                                style: TextStyle(fontSize: _fs, fontWeight: FontWeight.w700, color: Colors.black87),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('MR: ${patient.mrNo}  •  $since  •  Age: ${patient.age}',
                                style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade500)),
                          ])),
                        ]),
                      );
                    }).toList(),
                    onChanged: (mrNo) {
                      if (mrNo == null) return;
                      final patient = p.lookupPatient(mrNo);
                      if (patient != null) {
                        _fillPatient(patient);
                        _loadExistingTreatment(patient.mrNo, p);
                      }
                    },
                  );
                }
              ),
            ),
          ),
          SizedBox(height: _sh * 0.013),
          Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
          SizedBox(height: _sh * 0.012),
        ]);
      }),

      _lbl('Name'), _tf(_nameCtrl, filled: _patientFound),
      SizedBox(height: _sh * 0.01),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl('Age'), _tf(_ageCtrl, type: TextInputType.number, filled: _patientFound),
        ])),
        SizedBox(width: _sp),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _lbl('Gender'), _tf(_genderCtrl, filled: _patientFound),
        ])),
      ]),
      SizedBox(height: _sh * 0.01),
      if (_wide)
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Phone'), _tf(_phoneCtrl, type: TextInputType.phone, filled: _patientFound),
          ])),
          SizedBox(width: _sp),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _lbl('Address'), _tf(_addressCtrl, filled: _patientFound),
          ])),
        ])
      else ...[
        _lbl('Phone'), _tf(_phoneCtrl, type: TextInputType.phone, filled: _patientFound),
        SizedBox(height: _sh * 0.01),
        _lbl('Address'), _tf(_addressCtrl, filled: _patientFound),
      ],
      if (_patientFound) ...[
        SizedBox(height: _sh * 0.009),
        Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: _sw * 0.032),
          SizedBox(width: _sw * 0.01),
          Text('Patient found — all fields auto-filled',
              style: TextStyle(fontSize: _fsXS, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
        ]),
      ],
    ]));
  }

  // ──────────────────────────────────────
  //  2. MO / BED / ADMITTED SINCE
  // ──────────────────────────────────────
  Widget _moCard() => _card(
    _wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _labeled('MO (Medical Officer)', _moCtrl, hint: 'Enter MO')),
      SizedBox(width: _sp),
      Expanded(child: _labeled('Bed', _bedCtrl, hint: 'Bed #', type: TextInputType.number)),
      SizedBox(width: _sp),
      Expanded(flex: 2, child: _admittedWidget()),
    ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _labeled('MO (Medical Officer)', _moCtrl, hint: 'Enter MO'),
      SizedBox(height: _sh * 0.01),
      _labeled('Bed', _bedCtrl, hint: 'Bed #', type: TextInputType.number),
      SizedBox(height: _sh * 0.01),
      _admittedWidget(),
    ]),
  );

  Widget _labeled(String label, TextEditingController ctrl,
      {String hint = '', TextInputType type = TextInputType.text}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label), _tf(ctrl, hint: hint, type: type),
      ]);

  Widget _admittedWidget() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Admitted Since'),
    Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.013),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDE7),
        borderRadius: BorderRadius.circular(_sw * 0.022),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Text(_admCtrl.text,
          style: TextStyle(fontSize: _fs * 0.86, color: Colors.amber.shade800,
              fontFamily: 'monospace')),
    ),
  ]);

  // ──────────────────────────────────────
  //  3. VITALS
  // ──────────────────────────────────────
  Widget _vitalsCard() {
    final fields = [
      ('Pulse',     _pulseCtrl,  TextInputType.number),
      ('Temp',      _tempCtrl,   TextInputType.number),
      ('B.P.',      _bpCtrl,     TextInputType.text),
      ('Resp Rate', _respCtrl,   TextInputType.number),
      ('SPO₂',      _spo2Ctrl,   TextInputType.number),
      ('Weight',    _weightCtrl, TextInputType.number),
      ('Height',    _heightCtrl, TextInputType.number),
    ];
    final cols = _wide ? 7 : (_sw < 400 ? 3 : 4);

    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.favorite_rounded, color: danger, size: _sw * 0.042),
        SizedBox(width: _sw * 0.018),
        Text('Vitals', style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold, color: Colors.black87)),
      ]),
      SizedBox(height: _sh * 0.011),
      Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
      SizedBox(height: _sh * 0.011),
      GridView.count(
        crossAxisCount: cols,
        mainAxisSpacing: _sh * 0.01,
        crossAxisSpacing: _sw * 0.02,
        childAspectRatio: _wide ? 2.5 : (_sw < 400 ? 2.0 : 2.3),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: fields.map((f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _lbl(f.$1),
            Expanded(child: _tf(f.$2, type: f.$3, compact: true)),
          ],
        )).toList(),
      ),
    ]));
  }

  // ──────────────────────────────────────
  //  4. EMERGENCY SERVICES — DROPDOWN
  // ──────────────────────────────────────
  Widget _servicesCard(EmergencyProvider prov) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Row(children: [
        Icon(Icons.emergency_share_rounded, color: danger, size: _sw * 0.04),
        SizedBox(width: _sw * 0.015),
        Text('Emergency Services',
            style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold, color: Colors.black87)),
        const Spacer(),
        Consumer<EmergencyProvider>(builder: (_, p, __) => Container(
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.02, vertical: _sh * 0.003),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(_sw * 0.04),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text('PKR ${p.servicesTotalPrice.toStringAsFixed(0)}',
              style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w800, color: danger)),
        )),
      ]),
      SizedBox(height: _sh * 0.008),
      Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
      SizedBox(height: _sh * 0.01),

      // ── Dropdown to add service ──
      Container(
        height: _sh * 0.045,
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.02),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(_sw * 0.015),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<EmergencyService>(
            isExpanded: true,
            menuMaxHeight: 350,
            hint: Text('Add a service...',
                style: TextStyle(color: Colors.grey.shade400, fontSize: _fsS)),
            value: _selectedDropdownService,
            style: TextStyle(fontSize: _fsS, color: Colors.black87),
            icon: Icon(Icons.add_circle_outline_rounded, color: danger, size: _sw * 0.04),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(_sw * 0.02),
            items: prov.emergencyServices.map((svc) {
              final alreadyAdded = prov.isServiceSelected(svc.id);
              return DropdownMenuItem<EmergencyService>(
                value: svc,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      width: _sw * 0.05,
                      height: _sw * 0.05,
                      margin: EdgeInsets.only(right: _sw * 0.02),
                      decoration: BoxDecoration(
                        color: svc.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Builder(
                          builder: (context) {
                            if (svc.imageUrl != null) {
                              return CachedNetworkImage(
                                imageUrl: svc.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, _) => Icon(svc.icon, color: svc.color.withOpacity(0.5), size: _sw * 0.03),
                                errorWidget: (context, _, __) => Icon(svc.icon, color: svc.color.withOpacity(0.5), size: _sw * 0.03),
                              );
                            }
                            return Icon(svc.icon, color: alreadyAdded ? svc.color : Colors.grey, size: _sw * 0.035);
                          },
                        ),
                      ),
                    ),
                    Expanded(child: Text(svc.name,
                        style: TextStyle(
                          fontSize: _fsS,
                          fontWeight: alreadyAdded ? FontWeight.bold : FontWeight.normal,
                        ))),
                    Text('PKR ${svc.price.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade500)),
                  ]),
                ),
              );
            }).toList(),
            onChanged: (svc) {
              if (svc == null) return;
              prov.toggleService(svc);
              setState(() => _selectedDropdownService = null);
            },
          ),
        ),
      ),
      SizedBox(height: _sh * 0.01),

      // ── Selected services list ──
      Consumer<EmergencyProvider>(builder: (_, p, __) {
        if (p.selectedServices.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            Wrap(
              spacing: _sw * 0.015,
              runSpacing: _sh * 0.006,
              children: p.selectedServices.map((svc) {
                final isHourly = ['bed', 'nursing', 'hourly'].any((k) => svc.name.toLowerCase().contains(k));
                final startTime = _admCtrl.text.isEmpty || _admCtrl.text == 'Auto-filled from Emergency Receipt'
                    ? 'N/A'
                    : _admCtrl.text;
                final endTime = _fmtDt(DateTime.now());
                final tooltipMsg = 'Hourly Service\nStart Time: $startTime\nEnd Time: $endTime';

                final chip = Container(
                  padding: EdgeInsets.symmetric(horizontal: _sw * 0.02, vertical: _sh * 0.005),
                  decoration: BoxDecoration(
                    color: svc.color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(_sw * 0.015),
                    border: Border.all(color: svc.color.withOpacity(0.25)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: _sw * 0.035,
                      height: _sw * 0.035,
                      margin: EdgeInsets.only(right: _sw * 0.015),
                      decoration: BoxDecoration(
                        color: svc.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Builder(
                          builder: (context) {
                            if (svc.imageUrl != null) {
                              return CachedNetworkImage(
                                imageUrl: svc.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, _) => Icon(svc.icon, color: svc.color, size: _sw * 0.02),
                                errorWidget: (context, _, __) => Icon(svc.icon, color: svc.color, size: _sw * 0.02),
                              );
                            }
                            return Icon(svc.icon, color: svc.color, size: _sw * 0.025);
                          },
                        ),
                      ),
                    ),
                    Text(svc.name,
                        style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    SizedBox(width: _sw * 0.01),
                    GestureDetector(
                      onTap: () => p.removeSelectedService(svc.id),
                      child: Icon(Icons.cancel_rounded, color: svc.color.withOpacity(0.7), size: _sw * 0.035),
                    ),
                  ]),
                );

                if (isHourly) {
                  return Tooltip(
                    message: tooltipMsg,
                    textStyle: const TextStyle(color: Colors.white, fontSize: 11),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(8),
                    preferBelow: false,
                    child: chip,
                  );
                }
                return chip;
              }).toList(),
            ),
            SizedBox(height: _sh * 0.012),
            // ── Compact Bill Generate Button ──
            SizedBox(
              width: double.infinity,
              height: _sh * 0.042,
              child: ElevatedButton.icon(
                onPressed: () => _handleGenerateBill(p),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.015)),
                  elevation: 0,
                ),
                icon: Icon(Icons.receipt_long_rounded, size: _sw * 0.035),
                label: Text('Generate Bill — PKR ${p.servicesTotalPrice.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      }),
    ]));
  }

  // ──────────────────────────────────────
  //  5. COMPLAINT + MO NOTES
  // ──────────────────────────────────────
  Widget _notesCard() => _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _lbl('Complaint'),
    _tf(_complainCtrl, hint: 'Patient complaint...'),
    SizedBox(height: _sh * 0.013),
    _lbl('MO Notes'),
    TextField(
      controller: _notesCtrl,
      maxLines: 3,
      style: TextStyle(fontSize: _fs, color: Colors.black87),
      decoration: _dec('Medical officer notes...'),
    ),
  ]));

  // ──────────────────────────────────────
  //  6. DISCHARGE ROW
  // ──────────────────────────────────────
  Widget _dischargeCard() {
    final opts = ['Discharged', 'Admitted to Ward', 'Admitted to ICU', 'Referred', 'LAMA', 'Expired'];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _sw * 0.035, vertical: _sh * 0.012),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: _wide
          ? Row(children: [
        Expanded(child: Wrap(spacing: _sw * 0.005, children: opts.map(_radioOpt).toList())),
        _disCheck(),
      ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: _sw * 0.004, runSpacing: _sh * 0.004, children: opts.map(_radioOpt).toList()),
        SizedBox(height: _sh * 0.009),
        _disCheck(),
      ]),
    );
  }

  Widget _radioOpt(String label) => GestureDetector(
    onTap: () => setState(() => _disOpt = label),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Radio<String>(
        value: label, groupValue: _disOpt, activeColor: primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onChanged: (v) => setState(() => _disOpt = v!),
      ),
      Text(label, style: TextStyle(fontSize: _fsS, color: Colors.black87)),
    ]),
  );

  Widget _disCheck() => Row(mainAxisSize: MainAxisSize.min, children: [
    Checkbox(
      value: _discharged, activeColor: primary,
      onChanged: (v) => setState(() => _discharged = v ?? false),
    ),
    Text('Discharge Patient',
        style: TextStyle(fontSize: _fs, fontWeight: FontWeight.w700, color: Colors.black87)),
  ]);

  // ──────────────────────────────────────
  //  7. CLEAR + SAVE & PRINT
  // ──────────────────────────────────────
  Widget _bottomBtns(EmergencyProvider prov) => Row(children: [
    Expanded(child: OutlinedButton(
      onPressed: () => _clearAll(prov),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black54,
        side: BorderSide(color: Colors.grey.shade300),
        padding: EdgeInsets.symmetric(vertical: _sh * 0.016),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.025)),
      ),
      child: Text('Clear', style: TextStyle(fontSize: _fs, fontWeight: FontWeight.w600)),
    )),
    SizedBox(width: _sp),
    Expanded(flex: 2, child: ElevatedButton.icon(
      onPressed: () async => await _saveAndPrint(prov),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF9A9A),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: _sh * 0.016),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_sw * 0.025)),
      ),
      icon: Icon(Icons.print_rounded, size: _sw * 0.042),
      label: Text('Save & Print', style: TextStyle(fontSize: _fs, fontWeight: FontWeight.bold)),
    )),
  ]);

  // ════════════════════════════════════════
  //  RIGHT PANEL
  // ════════════════════════════════════════
  Widget _rightPanel(EmergencyProvider prov) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, _sh * 0.012, _pad * 0.5, _bp + _pad),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          _queueCard(prov),
          SizedBox(height: _sh * 0.012),
          _invMedCard(prov),
        ]),
      ),
    );
  }

  // ──────────────────────────────────────
  //  EMERGENCY PATIENTS QUEUE CARD
  // ──────────────────────────────────────
  Widget _queueCard(EmergencyProvider prov, {VoidCallback? onStateChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.012),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(_r), topRight: Radius.circular(_r)),
          ),
          child: Row(children: [
            Icon(Icons.emergency_rounded, color: danger, size: _sw * 0.035),
            SizedBox(width: _sw * 0.012),
            Expanded(child: Text('Emergency Patients',
                style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.bold, color: Colors.white))),
            Container(
              padding: EdgeInsets.symmetric(horizontal: _sw * 0.018, vertical: _sh * 0.003),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(_sw * 0.04),
              ),
              child: Text('${prov.queueCount} in queue',
                  style: TextStyle(fontSize: _fsXS, color: Colors.white70)),
            ),
          ]),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.009),
          child: Row(children: [
            Expanded(flex: 2, child: Text('MR #', style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w700, color: Colors.black54))),
            Expanded(flex: 3, child: Text('SINCE', style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w700, color: Colors.black54))),
            Expanded(flex: 4, child: Text('PATIENT', style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w700, color: Colors.black54))),
          ]),
        ),
        Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
        prov.queue.isEmpty
            ? Padding(
          padding: EdgeInsets.symmetric(vertical: _sh * 0.024),
          child: Center(child: Text('No emergency patients in queue',
              style: TextStyle(fontSize: _fsS, color: Colors.grey.shade400, fontStyle: FontStyle.italic))),
        )
            : Column(children: prov.queue.map((p) {
          final diff = DateTime.now().difference(p.admittedSince);
          final since = diff.inMinutes < 60 ? '${diff.inMinutes}m ago' : '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
          return GestureDetector(
            onTap: () {
              _fillPatient(p);
              _loadExistingTreatment(p.mrNo, prov);
              onStateChanged?.call();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.009),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
              child: Row(children: [
                Expanded(flex: 2, child: Text(p.mrNo, style: TextStyle(fontSize: _fsXS, color: Colors.black87))),
                Expanded(flex: 3, child: Text(since, style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade500))),
                Expanded(flex: 4, child: Text(p.name,
                    style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w600, color: Colors.black87),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          );
        }).toList()),
        Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
        TextButton.icon(
          onPressed: () {
            _syncOpdPatients();
            prov.refresh();
            onStateChanged?.call();
          },
          icon: Icon(Icons.refresh_rounded, size: _sw * 0.032, color: Colors.grey.shade500),
          label: Text('Refresh', style: TextStyle(fontSize: _fsS, color: Colors.grey.shade600)),
        ),
      ]),
    );
  }

  // ──────────────────────────────────────
  //  INVESTIGATIONS + MEDICINES TABBED CARD
  // ──────────────────────────────────────
  Widget _invMedCard(EmergencyProvider prov, {VoidCallback? onStateChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(children: [
        TabBar(
          controller: _rightTab,
          labelColor: danger,
          unselectedLabelColor: Colors.grey.shade500,
          indicatorColor: danger,
          indicatorWeight: _sw * 0.006,
          labelStyle: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w700, letterSpacing: 0.3),
          unselectedLabelStyle: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'INVESTIGATIONS'), Tab(text: 'MEDICINES')],
        ),
        Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
        SizedBox(
          height: _sh * 0.56,
          child: TabBarView(
            controller: _rightTab,
            children: [
              _investigationsView(prov, onStateChanged: onStateChanged),
              _medicinesView(prov, onStateChanged: onStateChanged),
            ],
          ),
        ),
      ]),
    );
  }

  // ── INVESTIGATIONS TAB ──
  Widget _investigationsView(EmergencyProvider prov, {VoidCallback? onStateChanged}) {
    final types = ['Lab', 'Ultra Sound', 'X-Ray', 'CT Scan', 'MRI'];

    final search = _invSearchCtrl.text.toLowerCase();
    List<String> items = [];
    if (_invType == 'Lab') {
      items = prov.labTests
          .map((e) => e['test_name']?.toString() ?? '')
          .where((name) => name.isNotEmpty && (search.isEmpty || name.toLowerCase().contains(search)))
          .toList();
    } else {
      final category = _invType == 'Ultra Sound' ? 'Ultrasound' : (_invType == 'CT Scan' ? 'CT-Scan' : _invType);
      items = prov.radiologyTests
          .where((e) => e['test_category']?.toString() == category)
          .map((e) => e['test_name']?.toString() ?? '')
          .where((name) => name.isNotEmpty && (search.isEmpty || name.toLowerCase().contains(search)))
          .toList();
    }

    return Column(children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.02, vertical: _sh * 0.007),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: types.map((t) => GestureDetector(
            onTap: () {
              setState(() {
                _invType = t;
                _invSearchCtrl.clear();
              });
              onStateChanged?.call();
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Radio<String>(
                value: t, groupValue: _invType, activeColor: danger,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (v) {
                  setState(() {
                    _invType = v!;
                    _invSearchCtrl.clear();
                  });
                  onStateChanged?.call();
                },
              ),
              Text(t, style: TextStyle(fontSize: _fsXS, color: Colors.black87)),
              SizedBox(width: _sw * 0.015),
            ]),
          )).toList()),
        ),
      ),
      Divider(height: 1, color: Colors.grey.shade200),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.008),
        child: TextField(
          controller: _invSearchCtrl,
          style: TextStyle(fontSize: _fsS),
          decoration: _dec('Search investigation...').copyWith(
            prefixIcon: const Icon(Icons.search, size: 16),
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          ),
          onChanged: (_) {
            setState(() {});
            onStateChanged?.call();
          },
        ),
      ),
      Divider(height: 1, color: Colors.grey.shade200),
      Expanded(child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final added = prov.addedInvestigations.any((a) => a.name.toLowerCase() == item.toLowerCase());
          return GestureDetector(
            onTap: () => prov.addInvestigation(_invType, item),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.0095),
              decoration: BoxDecoration(
                color: added ? primary.withOpacity(0.06) : Colors.transparent,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(children: [
                Expanded(child: Text(item, style: TextStyle(fontSize: _fsS, color: Colors.black87))),
                if (added) Icon(Icons.check_rounded, color: primary, size: _sw * 0.033),
              ]),
            ),
          );
        },
      )),
      Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.008),
        child: Row(children: [
          Expanded(child: Text('TYPE', style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w700, color: Colors.black54))),
          Expanded(flex: 2, child: Text('NAME', style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w700, color: Colors.black54))),
        ]),
      ),
      Divider(height: _sh * 0.001, color: const Color(0xFFEEEEEE)),
      prov.addedInvestigations.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: _sh * 0.012),
              child: Text('Click an item above to add',
                  style: TextStyle(fontSize: _fsS, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
            )
          : Container(
              height: _sh * 0.18,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: prov.addedInvestigations.length,
                itemBuilder: (_, idx) {
                  final inv = prov.addedInvestigations[idx];
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.007),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                    child: Row(children: [
                      Expanded(child: Text(inv.type, style: TextStyle(fontSize: _fsXS, color: Colors.grey.shade600))),
                      Expanded(flex: 2, child: Text(inv.name, style: TextStyle(fontSize: _fsXS, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      GestureDetector(
                        onTap: () => prov.removeInvestigation(inv.name),
                        child: Icon(Icons.close_rounded, color: Colors.red.shade300, size: _sw * 0.032),
                      ),
                    ]),
                  );
                },
              ),
            ),
      SizedBox(height: _sh * 0.008),
    ]);
  }

  // ── MEDICINES TAB ──
  Widget _medicinesView(EmergencyProvider prov, {VoidCallback? onStateChanged}) {
    final search = _medSearchCtrl.text.toLowerCase();
    final items = prov.medicinesList
        .map((e) => e['medicine_name']?.toString() ?? e['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty && (search.isEmpty || name.toLowerCase().contains(search)))
        .toList();

    return Column(children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.008),
        child: TextField(
          controller: _medSearchCtrl,
          style: TextStyle(fontSize: _fsS),
          decoration: _dec('Search medicine...').copyWith(
            prefixIcon: const Icon(Icons.search, size: 16),
            contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          ),
          onChanged: (_) {
            setState(() {});
            onStateChanged?.call();
          },
        ),
      ),
      Divider(height: 1, color: Colors.grey.shade200),
      Expanded(
        flex: 3,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (_, i) {
            final name = items[i];
            final presc = prov.isMedicinePrescribed(name);
            return GestureDetector(
              onTap: () => prov.toggleMedicine(name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.009),
                decoration: BoxDecoration(
                  color: presc ? primary.withOpacity(0.06) : Colors.transparent,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: Row(children: [
                  Icon(presc ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: presc ? primary : Colors.grey.shade400, size: _sw * 0.036),
                  SizedBox(width: _sw * 0.014),
                  Expanded(child: Text(name, style: TextStyle(fontSize: _fsS, fontWeight: FontWeight.w600, color: Colors.black87))),
                ]),
              ),
            );
          },
        ),
      ),
      Divider(height: 1, color: Colors.grey.shade200),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.006),
        child: Row(children: [
          Expanded(child: Text('NAME', style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w700, color: Colors.black54))),
          Text('PLAN x DAYS', style: TextStyle(fontSize: _fsXS, fontWeight: FontWeight.w700, color: Colors.black54)),
          SizedBox(width: _sw * 0.08),
        ]),
      ),
      Divider(height: 1, color: Colors.grey.shade200),
      Expanded(
        flex: 2,
        child: prov.prescribedMedicines.isEmpty
            ? Center(child: Text('Click a medicine above to add',
                style: TextStyle(fontSize: _fsS, color: Colors.grey.shade400, fontStyle: FontStyle.italic)))
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: prov.prescribedMedicines.length,
                itemBuilder: (_, i) {
                  final presc = prov.prescribedMedicines[i];
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: _sw * 0.028, vertical: _sh * 0.005),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
                    child: Row(children: [
                      Expanded(child: Text(presc.name, style: TextStyle(fontSize: _fsXS, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      Row(children: [
                        SizedBox(
                          width: _sw * 0.1,
                          height: 22,
                          child: TextField(
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            style: TextStyle(fontSize: _fsXS),
                            textAlign: TextAlign.center,
                            controller: TextEditingController(text: presc.plan)
                              ..selection = TextSelection.fromPosition(TextPosition(offset: presc.plan.length)),
                            onChanged: (val) => presc.plan = val,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Text('x', style: TextStyle(fontSize: _fsXS, color: Colors.grey)),
                        ),
                        SizedBox(
                          width: _sw * 0.07,
                          height: 22,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            style: TextStyle(fontSize: _fsXS),
                            textAlign: TextAlign.center,
                            controller: TextEditingController(text: presc.days)
                              ..selection = TextSelection.fromPosition(TextPosition(offset: presc.days.length)),
                            onChanged: (val) => presc.days = val,
                          ),
                        ),
                      ]),
                      SizedBox(width: _sw * 0.015),
                      GestureDetector(
                        onTap: () => prov.removeMedicine(presc.name),
                        child: Icon(Icons.close_rounded, color: Colors.red.shade300, size: _sw * 0.035),
                      ),
                    ]),
                  );
                },
              ),
      ),
    ]);
  }

  // ════════════════════════════════════════
  //  NARROW: popup dialogue for right panel
  // ════════════════════════════════════════
  void _openPopup(EmergencyProvider prov) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return ChangeNotifierProvider.value(
          value: prov,
          child: StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final double sw = MediaQuery.of(dialogContext).size.width;
              final double sh = MediaQuery.of(dialogContext).size.height;
              final double fsS = sw < 360 ? 10.0 : 11.5;

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.symmetric(
                    horizontal: sw >= 720 ? sw * 0.08 : sw * 0.025,
                    vertical: sh * 0.025),
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  resizeToAvoidBottomInset: true,
                  body: Container(
                    constraints: BoxConstraints(maxHeight: sh * 0.92),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(sw * 0.05),
                    ),
                    child: Column(children: [
                      // Header
                      Container(
                        padding: EdgeInsets.all(sw * 0.04),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(sw * 0.05),
                            topRight: Radius.circular(sw * 0.05),
                          ),
                        ),
                        child: Row(children: [
                          Icon(Icons.emergency_rounded,
                              color: Colors.white, size: sw * 0.048),
                          SizedBox(width: sw * 0.02),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Emergency Actions',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: sw * 0.042,
                                        fontWeight: FontWeight.bold)),
                                Text('Manage queue and prescriptions',
                                    style: TextStyle(color: Colors.white70, fontSize: fsS)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: EdgeInsets.all(sw * 0.018),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle),
                              child: Icon(Icons.close_rounded,
                                  color: Colors.white, size: sw * 0.042),
                            ),
                          ),
                        ]),
                      ),
                      // Body
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(sw * 0.035),
                          physics: const BouncingScrollPhysics(),
                          child: Consumer<EmergencyProvider>(
                            builder: (consumerContext, p, __) {
                              return Column(
                                children: [
                                  _queueCard(p, onStateChanged: () {
                                    setDialogState(() {});
                                  }),
                                  SizedBox(height: sh * 0.012),
                                  _invMedCard(p, onStateChanged: () {
                                    setDialogState(() {});
                                  }),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════
  //  SHARED HELPERS
  // ════════════════════════════════════════
  Widget _card(Widget child) => Container(
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(_r),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
    ),
    padding: EdgeInsets.all(_sw * 0.038),
    child: child,
  );

  Widget _lbl(String t) => Padding(
    padding: EdgeInsets.only(bottom: _sh * 0.004),
    child: Text(t, style: TextStyle(fontSize: _fsS, color: Colors.black54, fontWeight: FontWeight.w500)),
  );

  Widget _tf(TextEditingController ctrl, {
    String hint = '',
    TextInputType type = TextInputType.text,
    bool filled = false,
    bool compact = false,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        style: TextStyle(fontSize: _fs, color: Colors.black87),
        decoration: _dec(hint, filled: filled, compact: compact),
      );

  InputDecoration _dec(String hint, {bool filled = false, bool compact = false}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: _fs * 0.92),
        filled: true,
        fillColor: filled ? Colors.green.withOpacity(0.04) : Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(
          horizontal: _sw * 0.028,
          vertical: compact ? _sh * 0.008 : _sh * 0.013,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(_sw * 0.022),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_sw * 0.022),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_sw * 0.022),
            borderSide: const BorderSide(color: primary, width: 1.5)),
      );
}