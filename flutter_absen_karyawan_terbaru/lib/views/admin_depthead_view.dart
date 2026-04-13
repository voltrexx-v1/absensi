import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/app_constants.dart';
import '../services/api_service.dart';

class AdminDeptHeadView extends StatefulWidget {
  const AdminDeptHeadView({super.key});

  @override
  State<AdminDeptHeadView> createState() => _AdminDeptHeadViewState();
}

class _AdminDeptHeadViewState extends State<AdminDeptHeadView> {
  bool _showForm = false;
  bool _isSubmitting = false;
  
  bool _isEditing = false;
  String? _editDocId;

  final ScrollController _tableScrollController = ScrollController();

  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); 
  final TextEditingController _kontakController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  final TextEditingController _passController = TextEditingController(); 

  String _formDepartemen = 'Manajemen Site';
  String _formJabatan = 'Head Area';
  String _formArea = 'Semua Area'; 
  String _formJenisKelamin = 'Laki-laki';
  DateTime? _formTanggalLahir;
  String _formAgama = 'Islam';

  String _selectedAreaFilter = 'Semua Area';

  List<String> _availableAreas = ['Semua Area']; 
  List<String> _departemens = ['Manajemen Site', 'Umum'];
  List<String> _jabatans = ['Head Area', 'Manajer'];
  List<Map<String, dynamic>> _strukturOrganisasi = [];

  final List<String> _selectedUserIds = [];

  List<Map<String, dynamic>> _deptHeadUsers = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConfigs();
    _loadData();
  }

  Future<void> _loadData() async {
    final users = await ApiService.getUsers();
    final headUsers = users.where((u) => u['role'] == 'Head Area').toList();
    final att = await ApiService.getAttendances();
    if (mounted) setState(() { _deptHeadUsers = headUsers; _attendanceRecords = att; _isLoading = false; });
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    _namaController.dispose();
    _nikController.dispose();
    _emailController.dispose();
    _kontakController.dispose();
    _alamatController.dispose();
    _passController.dispose(); 
    super.dispose();
  }

  void _closeForm() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _showForm = false;
      _isEditing = false;
      _editDocId = null;
      _namaController.clear();
      _nikController.clear();
      _emailController.clear();
      _kontakController.clear();
      _alamatController.clear();
      _passController.clear();
      _formTanggalLahir = null;
      _formJenisKelamin = 'Laki-laki';
      _formAgama = 'Islam';
    });
  }

  Future<void> _fetchConfigs() async {
    try {
      var data = await ApiService.getConfig('site');
      if (data != null) {
        List<dynamic> locs = data['locations'] ?? [];
        if (mounted) {
          setState(() {
            if (locs.isNotEmpty) {
              Set<String> areaSet = locs.map((e) => e['siteName'].toString()).toSet();
              areaSet.remove('Semua Area');
              List<String> sortedAreas = areaSet.toList();
              sortedAreas.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _availableAreas = ['Semua Area', ...sortedAreas];
              if (sortedAreas.isNotEmpty && !_availableAreas.contains(_formArea)) _formArea = sortedAreas.first;
            } else {
              _availableAreas = ['Semua Area'];
              _formArea = 'Semua Area';
            }
            if (data.containsKey('struktur_organisasi')) {
              _strukturOrganisasi = List<Map<String, dynamic>>.from(data['struktur_organisasi']);
              Set<String> depSet = _strukturOrganisasi.map((e) => e['departemen'].toString()).toSet();
              List<String> sortedDeps = depSet.toList();
              sortedDeps.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _departemens = sortedDeps.isNotEmpty ? sortedDeps : ['Umum'];
              if (sortedDeps.isNotEmpty && !_departemens.contains(_formDepartemen)) _formDepartemen = sortedDeps.first;
              _updateJabatanList(_formDepartemen);
            } else {
              List<dynamic> depsData = data['departemens'] ?? ['Umum', 'Manajemen Site', 'Maintenance'];
              List<dynamic> jabsData = data['jabatans'] ?? ['Staff', 'Supervisor', 'Manajer', 'Head Area'];
              List<String> sortedDeps = depsData.map((e) => e.toString()).toList();
              sortedDeps.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _departemens = sortedDeps.isNotEmpty ? sortedDeps : ['Umum'];
              if (sortedDeps.isNotEmpty && !_departemens.contains(_formDepartemen)) _formDepartemen = sortedDeps.first;
              List<String> sortedJabs = jabsData.map((e) => e.toString()).toList();
              sortedJabs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              _jabatans = sortedJabs.isNotEmpty ? sortedJabs : ['Staff'];
              if (sortedJabs.isNotEmpty && !_jabatans.contains(_formJabatan)) _formJabatan = sortedJabs.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Gagal fetch config: $e");
    }
  }

  void _updateJabatanList(String departemen, {String? preserveJabatan}) {
      if (_strukturOrganisasi.isEmpty) return;
      var relatedJabs = _strukturOrganisasi.where((e) => e['departemen'] == departemen).map((e) => e['jabatan'].toString()).toSet().toList();
      relatedJabs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
          _jabatans = relatedJabs.isNotEmpty ? relatedJabs : ['Staff'];
          if (preserveJabatan != null && _jabatans.contains(preserveJabatan)) {
             _formJabatan = preserveJabatan;
          } else if (_jabatans.isNotEmpty) {
             if (!relatedJabs.contains(_formJabatan)) _formJabatan = relatedJabs.first;
          } else {
             _formJabatan = '';
          }
      });
  }

  Future<void> _submitDeptHead() async {
    FocusManager.instance.primaryFocus?.unfocus();
    String formNamaLengkap = _namaController.text.trim();
    String formNik = _nikController.text.trim();
    String formEmail = _emailController.text.trim();
    String formKontak = _kontakController.text.trim();
    String formAlamat = _alamatController.text.trim();
    String formPass = _passController.text.trim();

    if (formNamaLengkap.isEmpty || formNik.isEmpty || formEmail.isEmpty || _formDepartemen.isEmpty || _formJabatan.isEmpty || _formTanggalLahir == null || (!_isEditing && formPass.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap lengkapi semua field wajib (termasuk kata sandi baru)!"), backgroundColor: AppColors.rose500));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      Map<String, dynamic> payload = {
        'nama_lengkap': formNamaLengkap, 'nik': formNik, 'email': formEmail, 'jenis_kelamin': _formJenisKelamin,
        'tanggal_lahir': DateFormat('yyyy-MM-dd').format(_formTanggalLahir!), 'agama': _formAgama,
        'alamat': formAlamat.isNotEmpty ? formAlamat : '-', 'kontak': formKontak.isNotEmpty ? formKontak : '-',
        'departemen_id': _formDepartemen, 'jabatan': _formJabatan, 'area': _formArea.isNotEmpty ? _formArea : 'Semua Area', 'role': 'Head Area',
      };
      if (!_isEditing && formPass.isNotEmpty) payload['password'] = formPass;

      bool success;
      if (_isEditing && _editDocId != null) {
        success = await ApiService.updateUser(_editDocId!, payload);
        if (mounted && success) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Perubahan Berhasil Disimpan!"), backgroundColor: AppColors.emerald500));
      } else {
        payload['status_karyawan'] = 'Aktif';
        success = await ApiService.createUser(payload);
        if (mounted && success) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data Admin Area Berhasil Ditambahkan!"), backgroundColor: AppColors.emerald500));
      }
      if (success) { _closeForm(); _loadData(); }
      else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan data Admin Area."), backgroundColor: AppColors.rose500));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal menyimpan data Admin Area."), backgroundColor: AppColors.rose500));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteDeptHead(String docId, String nama) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: Colors.white,
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: AppColors.rose500), SizedBox(width: 8), Text("Hapus Data?", style: TextStyle(fontWeight: FontWeight.w900))]),
        content: Text("Apakah Anda yakin ingin menghapus data $nama secara permanen?", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(c, true), child: const Text("Hapus Permanen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ],
      )
    );

    if (confirm == true) {
      bool success = await ApiService.deleteUser(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? "Data berhasil dihapus." : "Gagal menghapus data."),
          backgroundColor: success ? AppColors.emerald500 : AppColors.rose500,
        ));
        if (success) _loadData();
      }
    }
  }

  Future<void> _resetAttendance(String docId, String nama) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: const [
            Icon(Icons.history_toggle_off, color: AppColors.amber500),
            SizedBox(width: 8),
            Text("Reset Absen Hari Ini?", style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(
          "Yakin ingin menghapus data absen hari ini untuk $nama? Aksi ini sangat berguna untuk mengulang simulasi absensi.",
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.slate600, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Batal", style: TextStyle(color: AppColors.slate400, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber500,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text("Reset Absen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );

    if (confirm == true) {
      bool success = await ApiService.deleteAttendance(docId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? "Data absen hari ini berhasil direset." : "Gagal mereset data."),
          backgroundColor: success ? AppColors.emerald500 : AppColors.rose500,
        ));
        if (success) _loadData();
      }
    }
  }

  void _editDeptHead(String docId, Map<String, dynamic> d) {
    setState(() {
      _isEditing = true; _editDocId = docId; _namaController.text = d['nama_lengkap'] ?? ''; _nikController.text = d['nik'] ?? ''; _emailController.text = d['email'] ?? ''; _kontakController.text = d['kontak'] ?? ''; _alamatController.text = d['alamat'] ?? ''; _passController.text = d['password'] ?? '';
      
      _formJenisKelamin = d['jenis_kelamin'] ?? 'Laki-laki'; 
      if (!['Laki-laki', 'Perempuan'].contains(_formJenisKelamin)) _formJenisKelamin = 'Laki-laki';
      
      _formAgama = d['agama'] ?? 'Islam';
      if (d['tanggal_lahir'] != null) { try { _formTanggalLahir = DateTime.parse(d['tanggal_lahir']); } catch(e) { _formTanggalLahir = null; } }
      _formArea = d['area'] ?? ''; if (!_availableAreas.contains(_formArea) && _availableAreas.isNotEmpty) _formArea = _availableAreas.first;
      _formDepartemen = d['departemen_id'] ?? ''; if (!_departemens.contains(_formDepartemen) && _departemens.isNotEmpty) _formDepartemen = _departemens.first;
      String existJabatan = d['jabatan'] ?? ''; _updateJabatanList(_formDepartemen, preserveJabatan: existJabatan);
      _showForm = true;
    });
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 46,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.yellow500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), padding: const EdgeInsets.symmetric(horizontal: 20)),
        onPressed: () { _closeForm(); setState(() => _showForm = true); },
        icon: const Icon(Icons.person_add, size: 16, color: AppColors.slate900), label: const Text("TAMBAH", style: TextStyle(color: AppColors.slate900, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("DATA ADMIN AREA", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5)),
              const SizedBox(height: 32),
              
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(40), border: Border.all(color: AppColors.slate100), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 10)]),
                clipBehavior: Clip.antiAlias,
                child: Builder(
                  builder: (context) {
                    if (_isLoading) return const Padding(padding: EdgeInsets.all(60.0), child: Center(child: CircularProgressIndicator(color: AppColors.emerald500)));

                    Map<String, Map<String, dynamic>> attendedUserRecords = {};
                    for (var d in _attendanceRecords) {
                      if (d['user_id'] != null && d['date'] == todayStr) {
                        attendedUserRecords[d['user_id'].toString()] = {'id': d['id'].toString(), ...d};
                      }
                    }

                    List<Map<String, dynamic>> users = List.from(_deptHeadUsers);
                    users.sort((a, b) => (a['nama_lengkap'] ?? '').toString().toLowerCase().compareTo((b['nama_lengkap'] ?? '').toString().toLowerCase()));

                    List<Map<String, dynamic>> displayedUsers = users.where((d) {
                      bool matchArea = _selectedAreaFilter == 'Semua Area' || (d['area'] ?? '') == _selectedAreaFilter;
                      return matchArea;
                    }).toList();

                    int totalLaki = displayedUsers.where((d) => (d['jenis_kelamin'] ?? '') == 'Laki-laki').length;
                    int totalPerempuan = displayedUsers.where((d) => (d['jenis_kelamin'] ?? '') == 'Perempuan').length;

                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.slate100))),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  bool isDesktopTab = constraints.maxWidth > 800;

                                  if (isDesktopTab) {
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.sort, color: AppColors.slate400, size: 20),
                                            const SizedBox(width: 12),
                                            Text("DAFTAR ADMIN AREA (${displayedUsers.length})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 2)),
                                          ]
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                               width: 250, height: 46, padding: const EdgeInsets.symmetric(horizontal: 16),
                                               decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)]),
                                               child: DropdownButtonHideUnderline(
                                                 child: DropdownButton<String>(
                                                   isExpanded: true, value: _availableAreas.contains(_selectedAreaFilter) ? _selectedAreaFilter : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
                                                   icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                   onChanged: (String? newValue) => setState(() => _selectedAreaFilter = newValue!),
                                                   items: _availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                 ),
                                               ),
                                            ),
                                            const SizedBox(width: 16),
                                            _buildAddButton(),
                                          ],
                                        ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.sort, color: AppColors.slate400, size: 16),
                                            const SizedBox(width: 12),
                                            Text("DAFTAR ADMIN AREA (${displayedUsers.length})", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 2)),
                                          ]
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                 height: 46, padding: const EdgeInsets.symmetric(horizontal: 16),
                                                 decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 4)]),
                                                 child: DropdownButtonHideUnderline(
                                                   child: DropdownButton<String>(
                                                     isExpanded: true, value: _availableAreas.contains(_selectedAreaFilter) ? _selectedAreaFilter : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
                                                     icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate500), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: 1),
                                                     onChanged: (String? newValue) => setState(() => _selectedAreaFilter = newValue!),
                                                     items: _availableAreas.map<DropdownMenuItem<String>>((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase(), overflow: TextOverflow.ellipsis))).toList(),
                                                   ),
                                                  ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            _buildAddButton(),
                                          ]
                                        )
                                      ]
                                    );
                                  }
                                }
                              )
                            ),
                            
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return RawScrollbar(
                                  controller: _tableScrollController,
                                  thumbVisibility: true,
                                  trackVisibility: false,
                                  thickness: 6,
                                  radius: const Radius.circular(20),
                                  thumbColor: AppColors.slate500.withValues(alpha: 0.6),
                                  child: SingleChildScrollView(
                                    controller: _tableScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth > 1000 ? constraints.maxWidth : 1000),
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(Colors.white),
                                        headingTextStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 2),
                                        dividerThickness: 1,
                                        dataRowMaxHeight: 90,
                                        columns: const [
                                          DataColumn(label: Text('PROFIL ADMIN AREA')),
                                          DataColumn(label: Text('INFO PERSONAL')),
                                          DataColumn(label: Text('POSISI & JABATAN')),
                                          DataColumn(label: Text('LOKASI / AREA')),
                                          DataColumn(label: Text('KONTAK & EMAIL')),
                                          DataColumn(label: Text('STATUS')),
                                          DataColumn(label: Text('ABSEN HARI INI')),
                                          DataColumn(label: Text('AKSI')),
                                        ],
                                        rows: displayedUsers.map((d) {
                                          String docId = (d['id'] ?? '').toString();

                                          String tglLahir = '-';
                                          if (d['tanggal_lahir'] != null && d['tanggal_lahir'].toString().isNotEmpty) {
                                            try { tglLahir = DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(d['tanggal_lahir'])); } catch (e) { tglLahir = d['tanggal_lahir']; }
                                          }

                                          bool hasAttended = attendedUserRecords.containsKey(docId);
                                          String? attDocId = hasAttended ? attendedUserRecords[docId]!['id'] : null;

                                          return DataRow(
                                            selected: _selectedUserIds.contains(docId),
                                            onSelectChanged: (val) {
                                              setState(() { if (val == true) { _selectedUserIds.add(docId); } else { _selectedUserIds.remove(docId); } });
                                            },
                                            cells: [
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text((d['nama_lengkap'] ?? 'Tanpa Nama').toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.slate800)),
                                                  const SizedBox(height: 4), Text(d['nik'] ?? '-', style: const TextStyle(fontSize: 11, color: AppColors.indigo500, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                                                ],
                                              )),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text((d['jenis_kelamin'] ?? '-').toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.slate800, fontWeight: FontWeight.w900)),
                                                  const SizedBox(height: 2), Text(tglLahir, style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                                                ],
                                              )),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text((d['departemen_id'] ?? 'MANAJEMEN SITE').toString().toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.slate800, fontWeight: FontWeight.w900)),
                                                  const SizedBox(height: 2), Text((d['jabatan'] ?? 'HEAD AREA').toString().toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.indigo50, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.indigo500)),
                                                    child: const Text('ADMIN AREA', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.indigo600, letterSpacing: 1)),
                                                  )
                                                ],
                                              )),
                                              DataCell(Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: AppColors.slate100, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(12)),
                                                child: Text((d['area'] ?? 'Belum Diatur').toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate600, letterSpacing: 1)),
                                              )),
                                              DataCell(Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text(d['kontak'] ?? '-', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                                                  const SizedBox(height: 2),
                                                  Text(d['email'] ?? '-', style: const TextStyle(fontSize: 10, color: AppColors.slate500, fontWeight: FontWeight.bold)),
                                                ],
                                              )),
                                              DataCell(Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: AppColors.emerald50, border: Border.all(color: AppColors.emerald200), borderRadius: BorderRadius.circular(12)),
                                                child: Text((d['status_karyawan'] ?? "AKTIF").toString().toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.emerald600, letterSpacing: 1)),
                                              )),
                                              DataCell(
                                                Builder(
                                                  builder: (context) {
                                                    String badgeText = "BELUM ABSEN";
                                                    Color badgeColor = AppColors.rose600;
                                                    Color badgeBg = AppColors.rose50;
                                                    Color badgeBorder = AppColors.rose200;
                                                    IconData badgeIcon = Icons.cancel;

                                                    if (hasAttended) {
                                                       var attData = attendedUserRecords[docId]!;
                                                       
                                                       if (attData['status_kehadiran'] != 'Hadir') {
                                                           badgeText = attData['status_kehadiran'].toString().toUpperCase();
                                                           badgeColor = AppColors.blue500;
                                                           badgeBg = AppColors.blue50;
                                                           badgeBorder = AppColors.blue500;
                                                           badgeIcon = Icons.info;
                                                       } else if (attData['jam_pulang'] != null) {
                                                           if (attData['status_pulang'] == 'Pulang Cepat') {
                                                               badgeText = "PULANG CEPAT";
                                                               badgeColor = AppColors.amber500;
                                                               badgeBg = AppColors.amber50;
                                                               badgeBorder = AppColors.amber500;
                                                               badgeIcon = Icons.exit_to_app;
                                                           } else {
                                                               badgeText = "SUDAH PULANG";
                                                               badgeColor = AppColors.emerald600;
                                                               badgeBg = AppColors.emerald50;
                                                               badgeBorder = AppColors.emerald200;
                                                               badgeIcon = Icons.check_circle;
                                                           }
                                                       } else if (attData['jam_masuk'] != null) {
                                                           badgeText = "SUDAH MASUK";
                                                           badgeColor = AppColors.indigo600;
                                                           badgeBg = AppColors.indigo50;
                                                           badgeBorder = AppColors.indigo400;
                                                           badgeIcon = Icons.login;
                                                       }
                                                    }

                                                    return Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                          decoration: BoxDecoration(
                                                            color: badgeBg,
                                                            border: Border.all(color: badgeBorder),
                                                            borderRadius: BorderRadius.circular(12)
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(badgeIcon, color: badgeColor, size: 12),
                                                              const SizedBox(width: 4),
                                                              Text(badgeText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: badgeColor, letterSpacing: 1)),
                                                            ]
                                                          )
                                                        ),
                                                        if (hasAttended) ...[
                                                          const SizedBox(width: 4),
                                                          IconButton(
                                                            icon: const Icon(Icons.refresh, size: 16, color: AppColors.slate400),
                                                            tooltip: "Reset Absen Hari Ini (Simulasi)",
                                                            constraints: const BoxConstraints(),
                                                            padding: EdgeInsets.zero,
                                                            onPressed: () => _resetAttendance(
                                                              attDocId!,
                                                              d['nama_lengkap'] ?? 'User',
                                                            ),
                                                          )
                                                        ]
                                                      ],
                                                    );
                                                  }
                                                )
                                              ),
                                              DataCell(
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(icon: const Icon(Icons.edit, size: 20, color: AppColors.blue500), tooltip: "Edit Data", style: IconButton.styleFrom(backgroundColor: AppColors.blue50), onPressed: () => _editDeptHead(docId, d)),
                                                    const SizedBox(width: 8),
                                                    IconButton(icon: const Icon(Icons.delete, size: 20, color: AppColors.rose500), tooltip: "Hapus Data", style: IconButton.styleFrom(backgroundColor: AppColors.rose50), onPressed: () => _deleteDeptHead(docId, d['nama_lengkap'] ?? 'User')),
                                                  ],
                                                )
                                              ),
                                            ]
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                );
                              }
                            ),
                            
                            if (displayedUsers.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(80),
                                child: Text("BELUM ADA DATA ADMIN AREA YANG TERDAFTAR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.slate400, letterSpacing: 1), textAlign: TextAlign.center),
                              ),
                              
                            if (displayedUsers.isNotEmpty) ...[
                              const Divider(height: 1, color: AppColors.slate100),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                color: AppColors.slate50, width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.end,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 24, runSpacing: 12,
                                  children: [
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.people, size: 14, color: AppColors.slate500), const SizedBox(width: 6), Text("TOTAL ADMIN AREA: ${displayedUsers.length}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate700, letterSpacing: 1))
                                    ]),
                                    Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.male, size: 14, color: AppColors.blue500), const SizedBox(width: 6), Text("LAKI-LAKI: $totalLaki", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.blue500, letterSpacing: 1))]),
                                    Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.female, size: 14, color: AppColors.rose500), const SizedBox(width: 6), Text("PEREMPUAN: $totalPerempuan", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.rose600, letterSpacing: 1))]),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                  }, 
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),

        // MODAL TAMBAH / EDIT DEPT HEAD
        if (_showForm) _buildAddDeptHeadModal(MediaQuery.of(context).size.width < 800),
      ],
    );
  }

  Widget _buildAddDeptHeadModal(bool isMobile) {
    String? dropdownAreaValue = _availableAreas.contains(_formArea) ? _formArea : (_availableAreas.isNotEmpty ? _availableAreas.first : null);
    String? dropdownDepValue = _departemens.contains(_formDepartemen) ? _formDepartemen : (_departemens.isNotEmpty ? _departemens.first : null);
    String? dropdownJabValue = _jabatans.contains(_formJabatan) ? _formJabatan : (_jabatans.isNotEmpty ? _jabatans.first : null);

    return Container(
      color: AppColors.slate900.withValues(alpha: 0.8),
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800), 
            padding: EdgeInsets.all(isMobile ? 24 : 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isMobile ? 32 : 48),
              boxShadow: const [BoxShadow(color: AppColors.black12, blurRadius: 20)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(_isEditing ? "EDIT ADMIN AREA" : "TAMBAH ADMIN AREA", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.slate800, letterSpacing: -0.5)),
                    ),
                    IconButton(
                      onPressed: () => _closeForm(),
                      icon: const Icon(Icons.close, color: AppColors.slate400),
                      tooltip: "Tutup"
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("NAMA LENGKAP", TextField(textInputAction: TextInputAction.next, controller: _namaController, decoration: _inputDeco("Nama Lengkap"))),
                        const SizedBox(height: 16),
                        _buildInputCol("NRP", TextField(textInputAction: TextInputAction.next, controller: _nikController, decoration: _inputDeco("NRP-XXX"))),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("NAMA LENGKAP", TextField(textInputAction: TextInputAction.next, controller: _namaController, decoration: _inputDeco("Nama Lengkap")))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("NRP", TextField(textInputAction: TextInputAction.next, controller: _nikController, decoration: _inputDeco("NRP-XXX")))),
                      ],
                    ),
                const SizedBox(height: 16),

                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("JENIS KELAMIN", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formJenisKelamin, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Laki-laki', 'Perempuan'].map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJenisKelamin = v!),
                        )),
                        const SizedBox(height: 16),
                        _buildInputCol("TANGGAL LAHIR", InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: _formTanggalLahir ?? DateTime(1980), firstDate: DateTime(1950), lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _formTanggalLahir = picked);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formTanggalLahir != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(_formTanggalLahir!) : "Pilih Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: _formTanggalLahir != null ? AppColors.slate800 : AppColors.slate400)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400),
                              ],
                            ),
                          ),
                        )),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("JENIS KELAMIN", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formJenisKelamin, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Laki-laki', 'Perempuan'].map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJenisKelamin = v!),
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("TANGGAL LAHIR", InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: _formTanggalLahir ?? DateTime(1980), firstDate: DateTime(1950), lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _formTanggalLahir = picked);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: AppColors.slate200), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formTanggalLahir != null ? DateFormat('dd MMMM yyyy', 'id_ID').format(_formTanggalLahir!) : "Pilih Tanggal", style: TextStyle(fontWeight: FontWeight.bold, color: _formTanggalLahir != null ? AppColors.slate800 : AppColors.slate400)),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.slate400),
                              ],
                            ),
                          ),
                        ))),
                      ],
                    ),
                const SizedBox(height: 16),

                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("AGAMA", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formAgama, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'].map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formAgama = v!),
                        )),
                        const SizedBox(height: 16),
                        _buildInputCol("NO. TELEPON", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.phone, controller: _kontakController, decoration: _inputDeco("No. HP Aktif"))),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("AGAMA", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formAgama, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: ['Islam', 'Kristen', 'Katolik', 'Hindu', 'Buddha', 'Konghucu'].map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formAgama = v!),
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("NO. TELEPON", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.phone, controller: _kontakController, decoration: _inputDeco("No. HP Aktif")))),
                      ],
                    ),
                const SizedBox(height: 16),

                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("ALAMAT EMAIL", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.emailAddress, controller: _emailController, decoration: _inputDeco("email@adminarea.com"))),
                        const SizedBox(height: 16),
                        _buildInputCol("ALAMAT LENGKAP", TextField(textInputAction: TextInputAction.next, maxLines: 2, controller: _alamatController, decoration: _inputDeco("Alamat Lengkap Admin Area"))),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("ALAMAT EMAIL", TextField(textInputAction: TextInputAction.next, keyboardType: TextInputType.emailAddress, controller: _emailController, decoration: _inputDeco("email@adminarea.com")))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("ALAMAT LENGKAP", TextField(textInputAction: TextInputAction.next, maxLines: 2, controller: _alamatController, decoration: _inputDeco("Alamat Lengkap Admin Area")))),
                      ],
                    ),
                const SizedBox(height: 16),
                
                isMobile 
                  ? Column(
                      children: [
                        _buildInputCol("DEPARTEMEN / DIVISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownDepValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _departemens.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formDepartemen = v!;
                              _updateJabatanList(v);
                            });
                          },
                        )),
                        const SizedBox(height: 16),
                        _buildInputCol("JABATAN / POSISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownJabValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _jabatans.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJabatan = v!),
                        )),
                      ]
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildInputCol("DEPARTEMEN / DIVISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownDepValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _departemens.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formDepartemen = v!;
                              _updateJabatanList(v);
                            });
                          },
                        ))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildInputCol("JABATAN / POSISI", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownJabValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _jabatans.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _formJabatan = v!),
                        ))),
                      ],
                    ),
                const SizedBox(height: 16),

                isMobile
                  ? Column(
                      children: [
                        _buildInputCol("AREA PENUGASAN (SITE YANG DIKELOLA)", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _availableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formArea = v!;
                            });
                          },
                        )),
                        if (!_isEditing) ...[
                           const SizedBox(height: 16),
                           _buildInputCol("KATA SANDI BARU", TextField(textInputAction: TextInputAction.done, onSubmitted: (_) => _submitDeptHead(), controller: _passController, obscureText: true, decoration: _inputDeco("Kata Sandi Rahasia"))),
                        ]
                      ]
                    )
                  : (!_isEditing)
                      ? Row(
                          children: [
                            Expanded(child: _buildInputCol("AREA PENUGASAN (SITE YANG DIKELOLA)", DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                              items: _availableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) {
                                setState(() {
                                  _formArea = v!;
                                });
                              },
                            ))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildInputCol("KATA SANDI BARU", TextField(textInputAction: TextInputAction.done, onSubmitted: (_) => _submitDeptHead(), controller: _passController, obscureText: true, decoration: _inputDeco("Kata Sandi Rahasia")))),
                          ],
                        )
                      : _buildInputCol("AREA PENUGASAN (SITE YANG DIKELOLA)", DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: dropdownAreaValue, icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.slate500), decoration: _inputDeco(""),
                          items: _availableAreas.map<DropdownMenuItem<String>>((e) => DropdownMenuItem<String>(value: e, child: Text(e, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) {
                            setState(() {
                              _formArea = v!;
                            });
                          },
                        )),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald500, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 10, shadowColor: AppColors.emerald500.withValues(alpha: 0.3)),
                    onPressed: _isSubmitting ? null : _submitDeptHead,
                    child: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                        : Text(_isEditing ? "SIMPAN PERUBAHAN" : "SIMPAN DATA ADMIN AREA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                  ),
                )

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCol(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.slate500, letterSpacing: 1)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.slate200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.yellow500, width: 2)),
    );
  }
}
