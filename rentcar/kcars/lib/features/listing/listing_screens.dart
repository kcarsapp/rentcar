import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kcars/core/services/api_service.dart';
import 'package:kcars/features/auth/data/model/profile.dart';
import 'package:kcars/features/auth/presentation/riverpod/current_user_controller.dart';
import 'listing_service.dart';

const listingRed = Color(0xFFB5121B);

ThemeData listingTheme(BuildContext context) => Theme.of(context).copyWith(
  scaffoldBackgroundColor: Colors.white,
  colorScheme: ColorScheme.fromSeed(
    seedColor: listingRed,
    brightness: Brightness.light,
  ).copyWith(primary: listingRed, onSurface: const Color(0xFF23262E)),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF6F6F7),
    labelStyle: const TextStyle(color: Color(0xFF626875)),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  ),
);

String listingImageUrl(String path) => path.startsWith('http')
    ? path
    : 'https://kcarsbucket.s3.amazonaws.com/${path.replaceFirst(RegExp(r'^/'), '')}';

class MyCarsScreen extends ConsumerStatefulWidget {
  const MyCarsScreen({super.key, required this.profile});
  final Profile profile;
  @override
  ConsumerState<MyCarsScreen> createState() => _MyCarsScreenState();
}

class _MyCarsScreenState extends ConsumerState<MyCarsScreen> {
  late final service = ListingService(GetIt.I<ApiService>());
  late Profile profile = widget.profile;
  final cars = <JsonMap>[];
  bool loading = true, more = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool next = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (!next) {
        profile = await service.refreshProfile();
        if (!mounted) return;
        await ref
            .read(currentUserControllerProvider.notifier)
            .setUserData(profile);
      }
      if (!canManageListings(profile)) {
        throw const FormatException(
          'Complete identity verification to post your personal car.',
        );
      }
      final page = await service.cars(
        profile,
        cursor: next && cars.isNotEmpty ? '${cars.last['id']}' : null,
      );
      if (!mounted) return;
      setState(() {
        if (!next) cars.clear();
        final ids = cars.map((c) => c['id']).toSet();
        cars.addAll(page.where((c) => !ids.contains(c['id'])));
        more = page.length == 15;
      });
    } catch (e) {
      if (mounted) setState(() => error = listingError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> edit([JsonMap? car]) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            ListingEditor(profile: profile, original: car, service: service),
      ),
    );
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
    await load();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: listingTheme(context),
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(personalOwner(profile) ? 'My cars' : 'Company cars'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Ready for the road',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                personalOwner(profile)
                    ? 'List your car with a little help from AI. Personal listings are reviewed by Carva before they go live.'
                    : 'Add and manage your company’s cars. Company listings do not need personal-listing approval.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                    loading || !canManageListings(profile) || error != null
                    ? null
                    : () => edit(),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Add a car'),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(error!),
                ),
                OutlinedButton(
                  onPressed: () => load(),
                  child: const Text('Try again'),
                ),
              ],
              if (!loading && error == null && cars.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 64,
                        color: listingRed,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Your first listing starts here',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Add photos, check the details, and set your rental prices.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              for (final car in cars)
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 1.8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: ListingPhotoView(
                            photo: listingList(car['images']).isEmpty
                                ? null
                                : ListingPhoto.remote(
                                    listingList(car['images']).first,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${car['title'] ?? 'Car'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit car',
                            onPressed: loading ? null : () => edit(car),
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: listingRed,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        car['available'] == true
                            ? 'Live'
                            : personalOwner(profile)
                            ? 'Awaiting review / unavailable'
                            : 'Unavailable',
                        style: TextStyle(
                          color: car['available'] == true
                              ? Colors.green.shade800
                              : Colors.orange.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              if (more && !loading)
                TextButton(
                  onPressed: () => load(next: true),
                  child: const Text('Load more cars'),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ListingPhotoView extends StatelessWidget {
  const ListingPhotoView({super.key, this.photo});
  final ListingPhoto? photo;
  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFF4F4F5),
      child: const Center(
        child: Icon(
          Icons.directions_car_outlined,
          size: 40,
          color: Colors.grey,
        ),
      ),
    );
    if (photo?.file != null) {
      return Image.file(
        photo!.file!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final path = photo?.existing?['image'];
    return path == null
        ? fallback
        : Image.network(
            listingImageUrl('$path'),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
  }
}

class ListingEditor extends StatefulWidget {
  const ListingEditor({
    super.key,
    required this.profile,
    required this.service,
    this.original,
  });
  final Profile profile;
  final ListingService service;
  final JsonMap? original;
  @override
  State<ListingEditor> createState() => _ListingEditorState();
}

class _ListingEditorState extends State<ListingEditor> {
  late final draft = ListingDraft(original: widget.original);
  late final title = TextEditingController(text: draft.title);
  late final year = TextEditingController(text: draft.year);
  late final vin = TextEditingController(text: draft.vin);
  final scroll = ScrollController();
  Map<String, List<JsonMap>>? catalogs;
  String? error, aiNote;
  bool busy = false, dirty = false, saved = false;
  int step = 0;
  @override
  void initState() {
    super.initState();
    loadCatalogs();
  }

  @override
  void dispose() {
    title.dispose();
    year.dispose();
    vin.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> loadCatalogs() async {
    setState(() {
      error = null;
      busy = true;
    });
    try {
      final result = await widget.service.catalogs();
      if (mounted) setState(() => catalogs = result);
    } catch (e) {
      if (mounted) setState(() => error = listingError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void change(VoidCallback action) {
    setState(() {
      action();
      dirty = true;
    });
  }

  Future<void> pick({bool forVin = false, bool camera = false}) async {
    try {
      final picker = ImagePicker();
      final List<XFile> files;
      if (forVin || camera) {
        final photo = await picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1800,
          imageQuality: 88,
        );
        files = photo == null ? [] : [photo];
      } else {
        files = await picker.pickMultiImage(maxWidth: 1800, imageQuality: 88);
      }
      if (!mounted || files.isEmpty) return;
      if (forVin) {
        change(() => draft.vinPhoto = File(files.first.path));
        return;
      }
      final room = 5 - draft.photos.length;
      if (files.length > room) {
        message('You can publish up to five car photos.');
      }
      change(
        () => draft.photos.addAll(
          files.take(room).map((p) => ListingPhoto.local(File(p.path))),
        ),
      );
    } catch (_) {
      if (mounted) {
        message(
          'Could not open photos. Check camera/photo access in your phone settings.',
        );
      }
    }
  }

  void next() {
    if (draft.photos.isEmpty) {
      message('Add at least one car photo first.');
      return;
    }
    change(() => step = 1);
    scroll.jumpTo(0);
  }

  Future<void> recognize() async {
    final photos = draft.photos.where((p) => p.file != null).toList();
    if (photos.isEmpty && draft.vinPhoto == null) {
      message('Add a new car photo or an optional VIN photo to use AI.');
      return;
    }
    if (draft.photos.isEmpty) {
      message('Add a car photo for your listing first.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      aiNote = null;
    });
    final notes = <String>[];
    var recognized = false;
    try {
      for (final file in [
        if (photos.isNotEmpty) photos.first.file!,
        if (draft.vinPhoto != null) draft.vinPhoto!,
      ]) {
        try {
          final result = await widget.service.recognize(
            file,
            catalogs!['brands'] ?? [],
          );
          if (!mounted) return;
          notes.addAll(draft.applyRecognition(result, catalogs!));
          final note = result['notes'];
          if (note is String && note.isNotEmpty) notes.add(note);
          recognized = true;
        } catch (e) {
          notes.add(listingError(e));
        }
      }
      if (!mounted) return;
      title.text = draft.title;
      year.text = draft.year;
      vin.text = draft.vin;
      setState(() {
        dirty = true;
        aiNote = [
          'Review the AI suggestions. Equipment can vary by trim; confirm everything before publishing.',
          ...notes.toSet(),
        ].join('\n');
        if (recognized) {
          step = 1;
        } else {
          error = notes.join('\n');
        }
      });
      if (recognized) scroll.jumpTo(0);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    final validation = draft.validate(catalogs!);
    if (validation != null) {
      message(validation);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final fresh = await widget.service.refreshProfile();
      final warning = await widget.service.save(draft, catalogs!, fresh);
      if (!mounted) return;
      setState(() => saved = true);
      // Allow PopScope to rebuild before returning the successful mutation.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(
            warning ??
                (widget.original != null
                    ? 'Car updated.'
                    : personalOwner(fresh)
                    ? 'Car submitted for admin review.'
                    : 'Car published.'),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              '${listingError(e)}\nIf the connection timed out, check My cars before submitting again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> leave() async {
    if (busy) return;
    if (step == 1) {
      setState(() => step = 0);
      scroll.jumpTo(0);
      return;
    }
    final discard =
        !dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Leave this draft?'),
                content: const Text('Unsaved changes will be lost.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep editing'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ) ==
            true;
    if (discard && mounted) {
      setState(() => saved = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Widget section(
    IconData icon,
    String label,
    List<Widget> children, {
    String? subtitle,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: listingRed, size: 23),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF626875)),
            ),
          ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  Widget dropdown(
    String label,
    String value,
    List<MapEntry<String, String>> items,
    ValueChanged<String> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label:$value:${items.length}'),
      initialValue: items.any((i) => i.key == value) ? value : null,
      isExpanded: true,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Color(0xFF23262E), fontSize: 16),
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (i) => DropdownMenuItem(
              value: i.key,
              child: Text(
                i.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: busy
          ? null
          : (v) {
              if (v != null) change(() => changed(v));
            },
    ),
  );

  Widget catalogField(
    String key,
    String label,
    String value,
    ValueChanged<String> changed,
  ) => dropdown(
    label,
    value,
    (catalogs?[key] ?? [])
        .map(
          (i) => MapEntry(
            '${i['id']}',
            catalogText(i, Localizations.localeOf(context).languageCode),
          ),
        )
        .toList(),
    changed,
  );

  Widget gallery() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (draft.photos.isNotEmpty)
        SizedBox(
          height: 150,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            itemCount: draft.photos.length,
            onReorderItem: (from, to) {
              if (!busy) {
                change(() {
                  draft.photos.insert(to, draft.photos.removeAt(from));
                });
              }
            },
            itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
              key: ObjectKey(draft.photos[i]),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 180,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: ListingPhotoView(photo: draft.photos[i]),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            i == 0 ? 'Cover photo' : '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IconButton.filled(
                          tooltip: 'Remove photo',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                          ),
                          onPressed: busy
                              ? null
                              : () => change(() => draft.photos.removeAt(i)),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: busy || draft.photos.length >= 5 ? null : () => pick(),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add photos'),
          ),
          IconButton.outlined(
            tooltip: 'Take car photo',
            onPressed: busy || draft.photos.length >= 5
                ? null
                : () => pick(camera: true),
            icon: const Icon(Icons.camera_alt_outlined),
          ),
        ],
      ),
      const SizedBox(height: 6),
      const Text(
        'Up to 5 photos. Hold and drag to reorder. The first photo is your cover.',
        style: TextStyle(fontSize: 13, color: Color(0xFF626875)),
      ),
    ],
  );

  List<Widget> firstStep() => [
    section(
      Icons.photo_library_outlined,
      'Car photos',
      [gallery()],
      subtitle:
          'Show the car clearly from different angles. Do not include VIN or identity documents in these public photos.',
    ),
    section(
      Icons.document_scanner_outlined,
      'VIN • optional',
      [
        TextField(
          controller: vin,
          enabled: !busy,
          textCapitalization: TextCapitalization.characters,
          maxLength: 17,
          decoration: const InputDecoration(
            labelText: 'Type VIN (optional)',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
          onChanged: (v) => change(() => draft.vin = v.toUpperCase().trim()),
        ),
        const SizedBox(height: 10),
        if (draft.vinPhoto != null)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 95,
                  height: 75,
                  child: Image.file(draft.vinPhoto!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('VIN photo\nNot part of your public gallery'),
              ),
              IconButton(
                tooltip: 'Remove VIN photo',
                onPressed: busy
                    ? null
                    : () => change(() => draft.vinPhoto = null),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : () => pick(forVin: true),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Add VIN photo'),
            ),
            IconButton.outlined(
              tooltip: 'Scan VIN with camera',
              onPressed: busy ? null : () => pick(forVin: true, camera: true),
              icon: const Icon(Icons.document_scanner_outlined),
            ),
          ],
        ),
      ],
      subtitle:
          'A clear VIN photo helps AI identify the model and year. A typed VIN is saved with your listing. VIN photos are never published.',
    ),
    FilledButton.icon(
      onPressed: busy || catalogs == null ? null : recognize,
      icon: const Icon(Icons.auto_awesome),
      label: Text(busy ? 'Please wait…' : 'Recognize car with AI'),
    ),
    const SizedBox(height: 10),
    OutlinedButton.icon(
      onPressed: busy || catalogs == null ? null : next,
      icon: const Icon(Icons.edit_note_outlined),
      label: const Text('Fill in details manually'),
    ),
  ];

  List<Widget> detailsStep() => [
    if (aiNote != null)
      Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBEFF0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(aiNote!),
      ),
    section(Icons.directions_car_outlined, 'Car details', [
      TextField(
        controller: title,
        enabled: !busy,
        maxLength: 100,
        decoration: const InputDecoration(
          labelText: 'Car name',
          hintText: 'e.g. Jeep Grand Cherokee L',
        ),
        onChanged: (v) => draft.title = v,
      ),
      const SizedBox(height: 10),
      catalogField('brands', 'Brand', draft.brandId, (v) => draft.brandId = v),
      catalogField('types', 'Body type', draft.typeId, (v) => draft.typeId = v),
      TextField(
        controller: year,
        enabled: !busy,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Model year'),
        onChanged: (v) => draft.year = v.trim(),
      ),
      const SizedBox(height: 14),
      dropdown('Transmission', draft.transmission, const [
        MapEntry('automatic', 'Automatic'),
        MapEntry('manual', 'Manual'),
        MapEntry('cvt', 'CVT'),
        MapEntry('amt', 'AMT'),
        MapEntry('dct', 'DCT'),
        MapEntry('sp', 'Sport'),
      ], (v) => draft.transmission = v),
      dropdown('Fuel', draft.fuel, const [
        MapEntry('gasoline', 'Gasoline'),
        MapEntry('diesel', 'Diesel'),
        MapEntry('electric', 'Electric'),
        MapEntry('hybird', 'Hybrid'),
        MapEntry('lpg', 'LPG'),
        MapEntry('cng', 'CNG'),
      ], (v) => draft.fuel = v),
      for (final spec in listingSpecLabels.entries)
        catalogField(
          spec.key,
          spec.value,
          draft.specIds[spec.key] ?? '',
          (v) => draft.specIds[spec.key] = v,
        ),
    ]),
    section(Icons.checklist_rounded, 'Features', [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final feature in listingAmenities.entries)
            FilterChip(
              label: Text(feature.value),
              selected: draft.amenities.contains(feature.key),
              avatar: Icon(amenityIcon(feature.key), size: 18),
              showCheckmark: false,
              onSelected: busy
                  ? null
                  : (selected) => change(() {
                      if (selected) {
                        draft.amenities.add(feature.key);
                      } else {
                        draft.amenities.remove(feature.key);
                      }
                    }),
            ),
        ],
      ),
    ], subtitle: 'Select only equipment that this car actually has.'),
    section(Icons.photo_library_outlined, 'Listing photos', [gallery()]),
    section(Icons.payments_outlined, 'Rental prices', [
      for (final plan in draft.plans)
        Container(
          key: ObjectKey(plan),
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${plan['periodType']}'.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove rental plan',
                    onPressed: busy
                        ? null
                        : () => change(() {
                            draft.plans.remove(plan);
                            if (draft.displayPlan == plan['periodType']) {
                              draft.displayPlan = draft.plans.isEmpty
                                  ? ''
                                  : '${draft.plans.first['periodType']}';
                            }
                          }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              TextFormField(
                initialValue: '${plan['price'] ?? ''}',
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price'),
                onChanged: (v) => plan['price'] = v,
              ),
              const SizedBox(height: 12),
              dropdown('Currency', '${plan['currency'] ?? 'usd'}', const [
                MapEntry('usd', 'USD'),
                MapEntry('iqd', 'IQD'),
              ], (v) => plan['currency'] = v),
              Material(
                color: Colors.transparent,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show this price on car cards'),
                  value: draft.displayPlan == plan['periodType'],
                  onChanged: busy
                      ? null
                      : (v) {
                          if (v) {
                            change(
                              () => draft.displayPlan = '${plan['periodType']}',
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ),
      if (draft.plans.length < 3)
        dropdown(
          'Add rental period',
          '',
          (catalogs!['plans'] ?? [])
              .where(
                (p) => !draft.plans.any(
                  (selected) => selected['periodType'] == p['periodType'],
                ),
              )
              .map((p) => MapEntry('${p['periodType']}', catalogText(p)))
              .toList(),
          (v) {
            draft.plans.add({
              'periodType': v,
              'price': '',
              'currency': 'usd',
              'available': true,
            });
            if (draft.plans.length == 1) draft.displayPlan = v;
          },
        ),
      const Text(
        'Choose up to three rental periods. Prices are yours to set; AI does not set them.',
        style: TextStyle(fontSize: 13, color: Color(0xFF626875)),
      ),
    ]),
    Text(
      personalOwner(widget.profile)
          ? 'Personal cars are sent to Carva for approval before customers can see them.'
          : 'Your company car will be visible to customers when published.',
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: busy ? null : save,
      icon: const Icon(Icons.check_circle_outline),
      label: Text(
        widget.original != null
            ? 'Save changes'
            : personalOwner(widget.profile)
            ? 'Submit for review'
            : 'Publish car',
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) => Theme(
    data: listingTheme(context),
    child: PopScope(
      canPop: saved,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: busy ? null : leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.original == null ? 'Add a car' : 'Edit car'),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Text(
                'STEP ${step + 1} OF 2',
                style: const TextStyle(
                  color: listingRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (step + 1) / 2,
                color: listingRed,
                backgroundColor: const Color(0xFFFBEFF0),
              ),
              const SizedBox(height: 24),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: LinearProgressIndicator(),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    error!,
                    style: const TextStyle(color: listingRed),
                  ),
                ),
              if (catalogs == null && !busy)
                OutlinedButton(
                  onPressed: loadCatalogs,
                  child: const Text('Reload form'),
                ),
              if (catalogs != null) ...step == 0 ? firstStep() : detailsStep(),
            ],
          ),
        ),
      ),
    ),
  );
}

IconData amenityIcon(String key) => switch (key) {
  'parking_sensors' => Icons.sensors,
  'apple_carplay' || 'android_auto' => Icons.phone_android,
  'rear_camera' => Icons.camera_rear_outlined,
  'cruise_control' || 'adaptive_cruise' => Icons.speed,
  'infotainment_screen' => Icons.touch_app_outlined,
  'smart_key' => Icons.key_outlined,
  'blind_spot_monitor' => Icons.visibility_outlined,
  'lane_assist' => Icons.add_road,
  'automatic_emergency_braking' => Icons.health_and_safety_outlined,
  'bluetooth' => Icons.bluetooth,
  'usb' => Icons.usb,
  'heated_seats' => Icons.airline_seat_recline_normal,
  'climate_control' => Icons.ac_unit,
  'sunroof' => Icons.wb_sunny_outlined,
  _ => Icons.directions_car_outlined,
};
