# frozen_string_literal: true

module Engine
  module Game
    module G1881
      module Map
        # JSON side N → Ruby side (N-1).  Layout is flat-top (horizontal).
        # Straight: sides differ by 3.  Gentle: differ by 2.  Sharp: differ by 1.

        TILES = {
          # --- Standard track tiles ---
          '1' => 1,
          '2' => 1,
          '3' => 4,
          '4' => 3,
          '5' => 6,
          '6' => 6,
          '7' => 15,
          '8' => 25,
          '9' => 15,
          '14' => 4,
          '15' => 4,
          '16' => 1,
          '17' => 1,
          '21' => 1,
          '22' => 1,
          '24' => 4,
          '25' => 4,
          '26' => 4,
          '27' => 4,
          '28' => 4,
          '29' => 4,
          '30' => 4,
          '31' => 4,
          '38' => 1,
          '39' => 2,
          '40' => 2,
          '41' => 2,
          '42' => 2,
          '43' => 2,
          '44' => 2,
          '45' => 2,
          '46' => 2,
          '47' => 2,
          '55' => 1,
          '56' => 1,
          '57' => 6,
          '58' => 3,
          '63' => 1,
          '69' => 1,
          '70' => 2,
          '87' => 2,
          '88' => 2,
          '441' => 2,
          '442' => 2,
          '443' => 2,
          '444' => 1,
          '448' => 1,
          '449' => 1,
          '611' => 1,
          '630' => 1,
          '631' => 1,
          '632' => 1,
          '633' => 1,

          # --- Custom city upgrade tiles for Hanoi (HN label) ---
          'HN' => {
            'count' => 1,
            'color' => 'yellow',
            'code' => 'city=revenue:50;path=a:1,b:_0;path=a:2,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=HN',
          },
          'HN2' => {
            'count' => 1,
            'color' => 'green',
            'code' => 'city=revenue:60,slots:2;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=HN',
          },
          'HN3' => {
            'count' => 1,
            'color' => 'brown',
            'code' => 'city=revenue:100,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=HN',
          },

          # --- Custom city upgrade tiles for Saigon (SG label) ---
          'SG' => {
            'count' => 1,
            'color' => 'yellow',
            'code' => 'city=revenue:30;path=a:0,b:_0;path=a:4,b:_0;label=SG',
          },
          'SG2' => {
            'count' => 1,
            'color' => 'green',
            'code' => 'city=revenue:70,slots:2;path=a:0,b:_0;path=a:1,b:_0;path=a:3,b:_0;path=a:4,b:_0;label=SG',
          },
          'SG3' => {
            'count' => 1,
            'color' => 'brown',
            'code' => 'city=revenue:90,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;path=a:5,b:_0;label=SG',
          },

          # --- Custom upgrade tiles for Hai Van Pass (HV label) ---
          # Green: town (pass) + city offset, paths on sides 3→2 and 1→0
          'HV2' => {
            'count' => 1,
            'color' => 'green',
            'code' => 'city=revenue:80,slots:2;path=a:0,b:_0;path=a:2,b:_0;label=HV',
          },
          'HV3' => {
            'count' => 1,
            'color' => 'brown',
            'code' => 'city=revenue:120,slots:3;path=a:0,b:_0;path=a:2,b:_0;label=HV',
          },
        }.freeze

        LOCATION_NAMES = {
          'A2' => 'Yunnan – China',
          'B3' => 'Lao Cai',
          'B31' => 'Cambodia',
          'B37' => 'Fishing Grounds',
          'C4' => 'Phu Tho & Yen Bai',
          'C8' => 'Moc Chau',
          'C30' => 'Phnom Penh',
          'C32' => 'Long Xuyen & Cao Lanh',
          'C38' => 'Ca Mau',
          'D33' => 'Can Tho',
          'D37' => 'Tra Vinh',
          'E6' => 'Hanoi',
          'E12' => 'Dong Hoi',
          'E14' => 'Laos',
          'E16' => 'Laos',
          'F7' => 'Ninh Binh & Nam Dinh',
          'F11' => 'Thanh Hoa',
          'F15' => 'Duc Minh & Huong Son',
          'F17' => 'Laos',
          'G4' => 'Bac Ninh',
          'G12' => 'Tan Mai & Hoang Mai',
          'G16' => 'Phong Nha',
          'G18' => 'Laos',
          'G26' => 'Cambodia',
          'G30' => 'Bien Hoa',
          'G32' => 'Saigon',
          'H3' => 'Thai Nguyen',
          'H13' => 'Vinh',
          'H21' => 'Kon Tum',
          'H33' => 'Vung Tau',
          'I2' => 'Guangxi – China',
          'I6' => 'Hai Phong',
          'I24' => 'Pleiku',
          'I28' => 'Buon Ma Thuot',
          'J5' => 'Ha Long',
          'J9' => 'Hainan – China',
          'J17' => 'Hue',
          'J31' => 'Phan Thiet & Lam Dong',
          'K2' => 'Mong Cai',
          'K4' => 'Quang Ninh',
          'K18' => 'Hai Van Pass',
          'K20' => 'Da Nang',
          'L23' => 'Quy Nhon',
          'L25' => 'Phu Yen & Tuy Hoa',
          'L29' => 'Nha Trang',
          'L33' => 'Hoang Sa & Truong Sa',
          'E38' => 'Con Dao',
          'G36' => 'Phu Quoc',
        }.freeze

        HEXES = {
          # OFFBOARD 
          red: {
            # Yunnan – China (northwest border)
            ['A2'] =>
              'offboard=revenue:yellow_40|green_70|brown_100;path=a:0,b:_0;path=a:5,b:_0',
            # Guangxi – China (north coast)
            ['I2'] =>
              'offboard=revenue:yellow_30|green_60|brown_100;path=a:1,b:_0',

            # Laos borders (west)
            ['E16'] =>
              'offboard=revenue:yellow_10|green_20|brown_40;path=a:4,b:5',
            ['E14'] =>
              'offboard=revenue:yellow_20|green_30|brown_50;path=a:3,b:5;path=a:4,b:_0',
            ['F17'] =>
              'offboard=revenue:yellow_20|green_30|brown_50;path=a:2,b:4;path=a:3,b:_0',
            ['G18'] =>
              'offboard=revenue:yellow_30|green_40|brown_50;path=a:3,b:5;path=a:4,b:_0',

            # Cambodia (southwest borders)
            ['B31'] =>
              'offboard=revenue:yellow_10|green_30|brown_60;path=a:0,b:_0;path=a:5,b:_0',
            ['C28'] =>
              'path=a:4,b:6',
            ['D27'] =>
              'path=a:1,b:4',
            ['E26'] =>
              'path=a:1,b:4',
            ['F25'] =>
              'path=a:5,b:1',

            # Phnom Penh (offboard city): straight sides 1,6 → Ruby 0,5
            ['C30'] =>
              'city=revenue:50;path=a:6,b:3;path=a:5,b:_0',

            # Cambodia hub (west of Saigon)
            ['G26'] =>
              'offboard=revenue:yellow_20|green_40|brown_70;path=a:0,b:_0;path=a:2,b:6;path=a:5,b:2',
          },

          # =====================================================================
          # WATER offboard hexes (coastal / sea routes with offboard revenue)
          # =====================================================================
          blue: {
            ['J19'] =>
              '',
            # Hainan – China sea: side 3 → Ruby 2
            ['J9'] =>
              'offboard=revenue:yellow_30|green_70|brown_90;path=a:2,b:_0',

            # Phu Quoc island: side 3 → Ruby 2
            ['G36'] =>
              'offboard=revenue:yellow_20|green_50|brown_100;path=a:2,b:_0',

            # Con Dao island: side 4 → Ruby 3
            ['E38'] =>
              'offboard=revenue:yellow_20|green_40|brown_60;path=a:3,b:_0',

            # Hoang Sa & Truong Sa archipelago: side 3 → Ruby 2
            ['L33'] =>
              'offboard=revenue:yellow_10|green_40|brown_60;path=a:2,b:_0',

            # Fishing Grounds (route bonus hex): side 6 → Ruby 5
            ['B37'] =>
              'offboard=revenue:yellow_20|green_40|brown_40;path=a:5,b:_0',

            # Coastal sea route connectors (permanent water track)
            # I8: gentle sides 4,6 → Ruby 3,5  (gentle: 3 and 5 differ by 2 ✓)
            ['I8'] => 'path=a:3,b:5;path=a:1,b:5',
            # H9: gentle side 3 → Ruby 2; gentle 2↔0
            ['H9'] => 'path=a:4,b:2',
            # G34: gentle side 2 → Ruby 1; gentle 1↔3
            ['G34'] => 'path=a:1,b:3',
            # F35: sharp side 5 → Ruby 4; sharp 4↔5
            ['F35'] => 'path=a:4,b:5',
            # K32: sharp side 5 → Ruby 4; sharp 4↔5
            ['K32'] => 'path=a:4,b:5',
            # L31: coastal town, value 20; sharp side 2 → Ruby 1 (1↔0), stub side 4 → Ruby 3
            ['L31'] => 'town=revenue:20;path=a:1,b:2;path=a:3,b:_0',
          },

          # =====================================================================
          # GRAY hexes (permanent, non-upgradeable)
          # =====================================================================
          gray: {
            # Northern border towns (value 10): gentle side 6 → Ruby 5; town stub
            %w[C2 E2 G2] => 'town=revenue:10;path=a:1,b:_0;path=a:5,b:_0',

            # D11: straight side 6 → Ruby 5; straight 5↔2
            ['D11'] => 'path=a:2,b:5',

            # E12: two gray towns (Dong Hoi area), gentle sides 4,1 → Ruby 3,0
            # gentle 3↔1 and gentle 0↔4 (approximation)
            ['E12'] => 'town=revenue:20;town=revenue:20;path=a:0,b:_0;path=a:2,b:_0;path=a:3,b:_1;path=a:5,b:_1',

            # H3: Thai Nguyen gray town, complex junction
            # straight side 2 → Ruby 1 (1↔4); stub side 3 → Ruby 2; sharp side 6 → Ruby 5 (5↔0)
            ['H3'] => 'town=revenue:20;path=a:0,b:5;path=a:1,b:_0;path=a:2,b:_0;path=a:4,b:_0',

            # A4: gentle side 4 → Ruby 3; gentle 3↔1
            ['A4'] => 'path=a:5,b:3',

            # J3: gentle side 6 → Ruby 5; gentle 5↔3
            ['J3'] => 'path=a:1,b:5',

            # K2: Mong Cai terminal gray town; straight stub side 1 → Ruby 0
            ['K2'] => 'town=revenue:30;path=a:0,b:_0',

            # F31: gentle side 6 → Ruby 5; gentle 5↔3
            ['F31'] => 'path=a:1,b:5',

            # F33: My Tho gray double-town, stub sides 5,2 → Ruby 4,1
            ['F33'] => 'town=revenue:30;town=revenue:30;path=a:1,b:_0;path=a:4,b:_1',

            # I26: mountain junction; straight side 1 → Ruby 0 (0↔3), gentle side 2 → Ruby 1 (1↔3)
            ['I26'] => 'path=a:0,b:3;path=a:1,b:3;path=a:6,b:1',

            # K30: coastal junction; sharp side 5 → Ruby 4 (4↔3), gentle side 6 → Ruby 5 (5↔3)
            ['K30'] => 'path=a:5,b:4;path=a:1,b:5',

            # L29: Nha Trang gray city (2 slots, CPA home), value 50
            # stubs on all 4 cardinal sides: sides 2,3,4,1 → Ruby 1,2,3,0
            ['L29'] => 'city=revenue:50,slots:2;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0',

            # Cambodia gray barriers (no track)
            %w[D29 E28 E30 F27 F29] => '',
          },

          # =====================================================================
          # YELLOW hexes (pre-placed yellow tiles, upgradeable)
          # =====================================================================
          yellow: {
            # K18: Hai Van Pass (pre-placed town with HV label, upgrades to HV2/HV3)
            ['K18'] => 'city=revenue:0;label=HV',
          },

          # =====================================================================
          # WHITE hexes (blank, upgradeable)
          # =====================================================================
          white: {
            # --- Blank terrain hexes (no city/town) ---
            # Plain blank (no terrain cost)
            %w[D5 D7 G14 E8 F5 F9 G6 G8 G10 E10 H15 I14 I30 I32
               J29 K24 K26 K28 L27 H27 G28 H29 H31 D31
               B33 C36 E34 L21] => '',

            # Mountain 60
            %w[B5 C6 C10 D3 F3 F13 H17 H19] =>
              'upgrade=cost:60,terrain:mountain',

            # Mountain 30
            %w[J23 J25 I22 D5 E4 F5] => 'upgrade=cost:30,terrain:mountain',

            # Water 60 (river crossing)
            %w[E32 K22 C34 D35 E36 I16] =>
              'upgrade=cost:60,terrain:water',

            # Water 40
            %w[H5 H7 E8 F7 G8 H31 I32 L27] => 'upgrade=cost:40,terrain:water',

            # Forest 30 (approximated as mountain terrain for cost)
            ['I20'] => 'upgrade=cost:30,terrain:mountain',

            # --- City hexes ---
            # Hanoi (HN label, CFI home)
            ['E6'] => 'city=revenue:0;label=HN',

            # Saigon (SG label, STC home)
            ['G32'] => 'city=revenue:0;label=SG',

            # Hai Phong (HPR home)
            ['I6'] => 'city=revenue:0',

            # Vinh (TIR home)
            ['H13'] => 'city=revenue:0',

            # Hue (RCL home)
            ['J17'] => 'city=revenue:0',

            # Da Nang (CFCA home)
            ['K20'] => 'city=revenue:0',

            # Moc Chau
            ['C8'] => 'city=revenue:0',

            # Bac Ninh (G4)
            ['G4'] => 'city=revenue:0',

            # Thanh Hoa (F11)
            ['F11'] => 'city=revenue:0',

            # Quy Nhon (L23)
            ['L23'] => 'city=revenue:0',

            # Can Tho (TMR home)
            ['D33'] => 'city=revenue:0',

            # Phong Nha (G16, mountain 60)
            ['G16'] => 'city=revenue:0;upgrade=cost:60,terrain:mountain',

            # Quang Ninh (K4, SFTC home)
            ['K4'] => 'city=revenue:0',

            # Lao Cai (TTC home, mountain 60)
            ['B3'] => 'city=revenue:0;upgrade=cost:60,terrain:mountain',

            # Pleiku (I24, mountain 60)
            ['I24'] => 'city=revenue:0;upgrade=cost:60,terrain:mountain',

            # Buon Ma Thuot (AT home, mountain 40)
            ['I28'] => 'city=revenue:0;upgrade=cost:40,terrain:mountain',

            # Ca Mau (FMT home, track stub side 3 → Ruby 2)
            ['C38'] => 'city=revenue:0',

            # --- Two-town hexes ---
            # Phu Tho & Yen Bai (C4, mountain 60)
            ['C4'] => 'town=revenue:0;town=revenue:0;upgrade=cost:60,terrain:mountain',

            # Ninh Binh & Nam Dinh (F7)
            ['F7'] => 'town=revenue:0;town=revenue:0;upgrade=cost:30,terrain:water',

            # Tan Mai & Hoang Mai (G12)
            ['G12'] => 'town=revenue:0;town=revenue:0',

            # Duc Minh & Huong Son (F15, mountain 60)
            ['F15'] => 'town=revenue:0;town=revenue:0;upgrade=cost:60,terrain:mountain',

            # Phu Yen & Tuy Hoa (L25)
            ['L25'] => 'town=revenue:0;town=revenue:0',

            # Long Xuyen & Cao Lanh (C32)
            ['C32'] => 'town=revenue:0;town=revenue:0',

            # Phan Thiet & Lam Dong (J31)
            ['J31'] => 'town=revenue:0;town=revenue:0',

            # --- Single-town hexes ---
            # Bien Hoa (G30)
            ['G30'] => 'town=revenue:0;upgrade=cost:30,terrain:mountain',

            # Ha Long (J5, water 40)
            ['J5'] => 'town=revenue:0;upgrade=cost:40,terrain:water',

            # Tra Vinh (D37, water 60)
            ['D37'] => 'town=revenue:0;upgrade=cost:60,terrain:water',

            # Vung Tau (H33, river 40)
            ['H33'] => 'town=revenue:0;upgrade=cost:40,terrain:water',

            # Kon Tum (H21, mountain 30 with town)
            ['H21'] => 'town=revenue:0;upgrade=cost:30,terrain:mountain',

            # Plain towns (no terrain)
            %w[J21 I18 J27 E4 I4 D9] => 'town=revenue:0',
          },
        }.freeze

        LAYOUT = :flat
      end
    end
  end
end
