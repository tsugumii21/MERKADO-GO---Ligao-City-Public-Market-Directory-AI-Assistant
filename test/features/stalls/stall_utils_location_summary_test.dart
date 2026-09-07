import 'package:flutter_test/flutter_test.dart';
import 'package:merkado_go/core/utils/stall_utils.dart';

void main() {
  group('StallUtils.formatLocation Tests', () {
    test('Returns address directly when section is empty or null', () {
      expect(
        StallUtils.formatLocation(null, 'Stall #12, Building 1'),
        equals('Stall #12, Building 1'),
      );
      expect(
        StallUtils.formatLocation('', 'Stall #12, Building 1'),
        equals('Stall #12, Building 1'),
      );
      expect(
        StallUtils.formatLocation('   ', 'Stall #12, Building 1'),
        equals('Stall #12, Building 1'),
      );
    });

    test('Returns formatted section fallback when address is empty', () {
      expect(
        StallUtils.formatLocation('Meat Section', ''),
        equals('Section Meat Section, Ligao Public Market'),
      );
      expect(
        StallUtils.formatLocation('Building II', '   '),
        equals('Section Building II, Ligao Public Market'),
      );
    });

    test('Returns fallback when both section and address are empty', () {
      expect(
        StallUtils.formatLocation(null, ''),
        equals('Ligao City Public Market'),
      );
      expect(
        StallUtils.formatLocation('', ''),
        equals('Ligao City Public Market'),
      );
    });

    test('De-duplicates section if address already contains the section name', () {
      expect(
        StallUtils.formatLocation(
          'BUILDING II',
          'STALL #22 BUILDING II MARKET SITE, LIGAO CITY',
        ),
        equals('STALL #22 BUILDING II MARKET SITE, LIGAO CITY'),
      );

      expect(
        StallUtils.formatLocation(
          'building ii',
          'STALL #22 BUILDING II MARKET SITE, LIGAO CITY',
        ),
        equals('STALL #22 BUILDING II MARKET SITE, LIGAO CITY'),
      );
    });

    test('Combines section and address when address does not contain section', () {
      expect(
        StallUtils.formatLocation('Meat Section', 'Stall #5'),
        equals('Meat Section • Stall #5'),
      );
    });
  });

  group('StallUtils.formatProductsSummary Tests', () {
    test('Returns empty string when products list is empty', () {
      expect(StallUtils.formatProductsSummary([]), equals(''));
    });

    test('Returns all products when count <= maxPreview (default 2)', () {
      expect(
        StallUtils.formatProductsSummary(['Bangus']),
        equals('Bangus'),
      );
      expect(
        StallUtils.formatProductsSummary(['Bangus', 'Tilapia']),
        equals('Bangus, Tilapia'),
      );
    });

    test('Returns preview plus count when count > maxPreview', () {
      expect(
        StallUtils.formatProductsSummary(['Bangus', 'Tilapia', 'Tuna']),
        equals('Bangus, Tilapia • +1 more'),
      );
      expect(
        StallUtils.formatProductsSummary(['Bangus', 'Tilapia', 'Tuna', 'Salmon', 'Shrimp']),
        equals('Bangus, Tilapia • +3 more'),
      );
    });
  });

  group('StallUtils.formatTagsSummary Tests', () {
    test('Returns empty string when tags list is empty', () {
      expect(StallUtils.formatTagsSummary([]), equals(''));
    });

    test('Returns formatted tags when count <= maxPreview', () {
      expect(
        StallUtils.formatTagsSummary(['wet_market']),
        equals('Wet Market'),
      );
      expect(
        StallUtils.formatTagsSummary(['wet_market', 'fresh_fish']),
        equals('Wet Market, Fresh Fish'),
      );
    });

    test('Returns formatted tags preview plus count when count > maxPreview', () {
      expect(
        StallUtils.formatTagsSummary(['wet_market', 'fresh_fish', 'organic', 'retail']),
        equals('Wet Market, Fresh Fish • +2 more'),
      );
    });
  });
}
