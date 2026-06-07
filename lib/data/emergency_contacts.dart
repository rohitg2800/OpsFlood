// lib/data/emergency_contacts.dart
// OpsFlood — Bihar Emergency Contacts Registry
// Sources: NDMA, Bihar SDMA, WRD Bihar, district collector websites (2024-25)
library;

enum ContactType { national, state, district, medical, ngo }

class EmergencyContact {
  final String name;
  final String number;
  final String? subtitle;
  final ContactType type;
  const EmergencyContact({
    required this.name,
    required this.number,
    this.subtitle,
    required this.type,
  });
}

// ── NATIONAL ──────────────────────────────────────────────────────────────────
const List<EmergencyContact> kNationalContacts = [
  EmergencyContact(
    name: 'NDRF Helpline',
    number: '9711077372',
    subtitle: 'National Disaster Response Force',
    type: ContactType.national,
  ),
  EmergencyContact(
    name: 'National Emergency',
    number: '112',
    subtitle: 'Police / Fire / Ambulance (unified)',
    type: ContactType.national,
  ),
  EmergencyContact(
    name: 'NDMA Control Room',
    number: '1078',
    subtitle: 'National Disaster Management Authority',
    type: ContactType.national,
  ),
  EmergencyContact(
    name: 'Army Helpline',
    number: '1800-180-1253',
    subtitle: 'Indian Army flood relief (toll-free)',
    type: ContactType.national,
  ),
];

// ── STATE ─────────────────────────────────────────────────────────────────────
const List<EmergencyContact> kStateContacts = [
  EmergencyContact(
    name: 'Bihar Flood Control Room',
    number: '06122294204',
    subtitle: 'WRD Bihar — 24×7 during monsoon',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'BSDMA Helpline',
    number: '06122294204',
    subtitle: 'Bihar State Disaster Management Authority',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'Bihar CM Helpline',
    number: '1800-345-6188',
    subtitle: 'Chief Minister Relief Fund (toll-free)',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'SDRF Bihar',
    number: '0612-2217755',
    subtitle: 'State Disaster Response Force HQ Patna',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'CWC Patna',
    number: '0612-2224251',
    subtitle: 'Central Water Commission — Flood Forecasting',
    type: ContactType.state,
  ),
  EmergencyContact(
    name: 'Patna Ambulance',
    number: '102',
    subtitle: 'Free ambulance service across Bihar',
    type: ContactType.state,
  ),
];

// ── DISTRICT CONTROL ROOMS ────────────────────────────────────────────────────
const List<EmergencyContact> kDistrictContacts = [
  EmergencyContact(
    name: 'Patna DM Office',
    number: '0612-2219810',
    subtitle: 'District Magistrate — Patna',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Muzaffarpur DM',
    number: '0621-2213100',
    subtitle: 'District Magistrate — Muzaffarpur',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Darbhanga DM',
    number: '06272-222226',
    subtitle: 'District Magistrate — Darbhanga',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Supaul DM',
    number: '06473-222024',
    subtitle: 'District Magistrate — Supaul (Kosi belt)',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Sitamarhi DM',
    number: '06226-244250',
    subtitle: 'District Magistrate — Sitamarhi (Bagmati belt)',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Bhagalpur DM',
    number: '0641-2400455',
    subtitle: 'District Magistrate — Bhagalpur',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Madhubani DM',
    number: '06276-222213',
    subtitle: 'District Magistrate — Madhubani (Kamla belt)',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Gopalganj DM',
    number: '06150-222250',
    subtitle: 'District Magistrate — Gopalganj (Gandak belt)',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Katihar DM',
    number: '06452-242624',
    subtitle: 'District Magistrate — Katihar (Kosi outfall)',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Samastipur DM',
    number: '06274-222015',
    subtitle: 'District Magistrate — Samastipur',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Vaishali DM',
    number: '0621-2283200',
    subtitle: 'District Magistrate — Vaishali (Gandak)',
    type: ContactType.district,
  ),
  EmergencyContact(
    name: 'Siwan DM',
    number: '06154-242208',
    subtitle: 'District Magistrate — Siwan (Ghaghra)',
    type: ContactType.district,
  ),
];

// ── MEDICAL & NGO ─────────────────────────────────────────────────────────────
const List<EmergencyContact> kMedicalContacts = [
  EmergencyContact(
    name: 'PMCH Patna',
    number: '0612-2300008',
    subtitle: 'Patna Medical College & Hospital (trauma)',
    type: ContactType.medical,
  ),
  EmergencyContact(
    name: 'IGIMS Patna',
    number: '0612-2297260',
    subtitle: 'Indira Gandhi Institute of Medical Sciences',
    type: ContactType.medical,
  ),
  EmergencyContact(
    name: 'AIIMS Patna',
    number: '0612-2451070',
    subtitle: 'All India Institute of Medical Sciences',
    type: ContactType.medical,
  ),
  EmergencyContact(
    name: 'Red Cross Bihar',
    number: '0612-2223500',
    subtitle: 'Indian Red Cross Society — Bihar Chapter',
    type: ContactType.ngo,
  ),
  EmergencyContact(
    name: 'Oxfam India Bihar',
    number: '011-46538000',
    subtitle: 'Flood relief & rehabilitation',
    type: ContactType.ngo,
  ),
  EmergencyContact(
    name: 'UNICEF Bihar',
    number: '011-24600222',
    subtitle: 'Child emergency during floods',
    type: ContactType.ngo,
  ),
];
