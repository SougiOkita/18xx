# frozen_string_literal: true

module Engine
  module Game
    module G1881
      module Entities
        COMPANIES = [
          # === Concessions (immediately float a major corporation) ===
          # 1a/1b = North pair (random pick); 2a/2b = Central pair; 3a/3b = South pair (random pick)
          {
            name: 'Concession 1a – CFI',
            sym: 'CFI-C',
            value: 130,
            revenue: 0,
            desc: 'Once purchased, immediately float and gain the director share for Chemins de fer de '\
                  "l'Indochine. Par price equals half the bid price, rounded down to the nearest par price.",
            color: nil,
          },
          {
            name: 'Concession 1b – HPR',
            sym: 'HPR-C',
            value: 130,
            revenue: 0,
            desc: 'Once purchased, immediately float and gain the director share for Chemin de fer de '\
                  'Hai Phong. Par price equals half the bid price, rounded down to the nearest par price.',
            color: nil,
          },
          {
            name: 'Concession 2a – CFCA',
            sym: 'CFCA-C',
            value: 130,
            revenue: 0,
            desc: 'Once purchased, immediately float and gain the director share for Compagnie Française '\
                  "des Chemins de Fer de l'Annam. Par price equals half the bid price, rounded down to "\
                  'the nearest par price.',
            color: nil,
          },
          {
            name: 'Concession 2b – RCL',
            sym: 'RCL-C',
            value: 130,
            revenue: 0,
            desc: "Once purchased, immediately float and gain the director share for Réseaux non concédés "\
                  "de l'Indochine. Par price equals half the bid price, rounded down to the nearest par price.",
            color: nil,
          },
          {
            name: 'Concession 3a – STC',
            sym: 'STC-C',
            value: 130,
            revenue: 0,
            desc: 'Once purchased, immediately float and gain the director share for Société générale des '\
                  'tramways à vapeur de Cochinchine. Par price equals half the bid price, rounded down to '\
                  'the nearest par price.',
            color: nil,
          },
          {
            name: 'Concession 3b – TMR',
            sym: 'TMR-C',
            value: 130,
            revenue: 0,
            desc: 'Once purchased, immediately float and gain the director share for Chemin de fer de '\
                  'Trans-Mékong. Par price equals half the bid price, rounded down to the nearest par price.',
            color: nil,
          },

          # === Central Railway share certificates ===
          {
            name: 'Central Railway – Hai Van Pass',
            sym: 'C1',
            value: 60,
            revenue: 5,
            desc: 'When purchased, receive one share of a Central Concession corporation (CFCA or RCL). '\
                  'The full bid price is paid to that corporation instead of the bank.',
            color: nil,
          },
          {
            name: 'Central Railway – Hai Van Pass',
            sym: 'C2',
            value: 60,
            revenue: 5,
            desc: 'When purchased, receive one share of a Central Concession corporation (CFCA or RCL). '\
                  'The full bid price is paid to that corporation instead of the bank.',
            color: nil,
          },
          {
            name: 'Central Railway – Hai Van Pass (4p)',
            sym: 'C1+',
            value: 60,
            revenue: 5,
            desc: 'When purchased, receive one share of a Central Concession corporation (CFCA or RCL). '\
                  'The full bid price is paid to that corporation instead of the bank.',
            color: nil,
          },
          {
            name: 'Central Railway – Hai Van Pass (4p)',
            sym: 'C2+',
            value: 60,
            revenue: 5,
            desc: 'When purchased, receive one share of a Central Concession corporation (CFCA or RCL). '\
                  'The full bid price is paid to that corporation instead of the bank.',
            color: nil,
          },

          # === Central utility privates ===
          {
            name: 'Hai Van Pass Survey Commission',
            sym: 'C3',
            value: 150,
            revenue: 10,
            max_price: 150,
            desc: 'Reserves a share in a Central Concession corporation. While held by a player, '\
                  'blocks K18 (Hai Van Pass) from being upgraded. '\
                  'A player may redeem it, at any point during a Stock Round, for the reserved Central '\
                  'Concession share; the private is not closed by this and its income drops to ₫0, but '\
                  'it may still be sold to a corporation afterward. If sold to a corporation unredeemed, '\
                  'the reserved share returns to that corp\'s IPO; the corporation may then close this '\
                  'private for a free tile upgrade on K18 (token placement is not free). K18 can only be '\
                  'upgraded to HV tiles. May only be sold to a corporation for up to its face value (not '\
                  'the usual 2x).',
            color: nil,
          },
          {
            name: 'Indochine Express – Laos',
            sym: 'C4',
            value: 150,
            revenue: 10,
            desc: 'When purchased by a corporation, immediately converted to the Laos Export Contract. '\
                  'The contract grants +₫10 revenue per Laos hex visited on each route.',
            color: nil,
          },

          # === Northern privates ===
          {
            name: 'Société Française des Charbonnages du Tonkin',
            sym: 'N1',
            value: 130,
            revenue: 0,
            desc: 'Gain the director\'s share of SFTC. Par price equals half the bid price, rounded down '\
                  'to the nearest par price.',
            color: nil,
          },
          {
            name: 'Yunnan Trading Contract',
            sym: 'N2',
            value: 60,
            revenue: 5,
            desc: 'When purchased, receive one share of the North Concession corporation (CFI or HPR). '\
                  'The bid price is paid to that corporation instead of the bank.',
            color: nil,
          },
          {
            name: 'Export Commission of Hai Phong',
            sym: 'N3',
            value: 150,
            revenue: 5,
            max_price: 150,
            desc: 'Reserves a share in the North Concession. The owning player may redeem it, at any '\
                  'point during a Stock Round, for the reserved North Concession share; the private is '\
                  'not closed by this and its income drops to ₫0, but it may still be sold to a '\
                  'corporation afterward. If sold to a corporation unredeemed, the reserved share '\
                  'returns to that corp\'s IPO. Can be discarded to place the port bonus token (+30 to '\
                  'a port city). May only be sold to a corporation for up to its face value (not the '\
                  'usual 2x).',
            color: nil,
          },
          {
            name: 'Northern Construction Commission',
            sym: 'N4',
            value: 150,
            revenue: 10,
            max_price: 150,
            desc: 'Reserves a share in the North Concession. The owning player may redeem it, at any '\
                  'point during a Stock Round, for the reserved North Concession share; the private is '\
                  'not closed by this and its income drops to ₫0, but it may still be sold to a '\
                  'corporation afterward. If sold to a corporation unredeemed, the reserved share '\
                  'returns to that corp\'s IPO. The owner may also make a free placement or upgrade of '\
                  'one city or town tile with a +30 city bonus token. May only be sold to a corporation '\
                  'for up to its face value (not the usual 2x).',
            color: nil,
          },

          # === Southern privates ===
          {
            name: 'Mekong Delta Trading Contract',
            sym: 'S1',
            value: 60,
            revenue: 5,
            desc: 'When purchased, receive one share of the South Concession corporation (STC or TMR). '\
                  'The bid price is paid to that corporation instead of the bank.',
            color: nil,
          },
          {
            name: 'Mekong Delta Trading Contract',
            sym: 'S2',
            value: 60,
            revenue: 5,
            desc: 'When purchased, receive one share of the South Concession corporation (STC or TMR). '\
                  'The bid price is paid to that corporation instead of the bank.',
            color: nil,
          },
          {
            name: 'Société de produits de la mer',
            sym: 'S3',
            value: 130,
            revenue: 10,
            desc: 'Gain the director\'s share of FMT. Par price equals half the bid price, rounded down '\
                  'to the nearest par price.',
            color: nil,
          },
          {
            name: 'Indochine Express – Cambodia',
            sym: 'S4',
            value: 150,
            revenue: 10,
            max_price: 150,
            desc: 'Reserves a share in the South Concession. The owning player may redeem it, at any '\
                  'point during a Stock Round, for the reserved South Concession share; the private is '\
                  'not closed by this and its income drops to ₫0, but it may still be sold to a '\
                  'corporation afterward. If sold to a corporation unredeemed, the reserved share '\
                  'returns to that corp\'s IPO. A corporation owning this private may close it to place '\
                  'a free token on C30 (Phnom Penh), which is what lets it route through the Cambodia '\
                  'gate (C28/D27/E26/F25) to reach G26. May only be sold to a corporation for up to its '\
                  'face value (not the usual 2x).',
            abilities: [{
              type: 'token',
              owner_type: 'corporation',
              hexes: ['C30'],
              price: 0,
              count: 1,
              extra_action: true,
              from_owner: false,
              closed_when_used_up: true,
            }],
            color: nil,
          },
        ].freeze

        CORPORATIONS = [
          # === Major corporations (mainline) ===
          {
            sym: 'CFI',
            name: "Chemins de fer de l'Indochine",
            logo: '1881/CFI',
            simple_logo: '1881/CFI.alt',
            float_percent: 20,
            float_includes_reserved: true,
            tokens: [0, 50, 80, 100, 100],
            coordinates: 'E6',
            color: '#d4af00',
            text_color: 'black',
          },
          {
            sym: 'STC',
            name: 'Société générale des tramways à vapeur de Cochinchine',
            logo: '1881/STC',
            simple_logo: '1881/STC.alt',
            float_percent: 20,
            float_includes_reserved: true,
            tokens: [0, 50, 80, 100, 100],
            coordinates: 'G32',
            color: '#e06666',
            text_color: 'black',
          },
          {
            sym: 'RCL',
            name: "Réseaux non concédés de l'Indochine",
            logo: '1881/RCL',
            simple_logo: '1881/RCL.alt',
            float_percent: 20,
            float_includes_reserved: true,
            tokens: [0, 50, 80, 100],
            coordinates: 'J17',
            color: '#b4a7d6',
            text_color: 'black',
          },
          {
            sym: 'CFCA',
            name: "Compagnie Française des Chemins de Fer de l'Annam",
            logo: '1881/CFCA',
            simple_logo: '1881/CFCA.alt',
            float_percent: 20,
            float_includes_reserved: true,
            tokens: [0, 50, 80, 100],
            coordinates: 'K20',
            color: '#f9cb9c',
            text_color: 'black',
          },
          {
            sym: 'TIR',
            name: 'Transindochinois Railway',
            logo: '1881/TIR',
            simple_logo: '1881/TIR.alt',
            float_percent: 20,
            tokens: [0, 50, 80, 100],
            coordinates: 'H13',
            color: '#a4c2f4',
            text_color: 'black',
          },
          {
            sym: 'TTC',
            name: 'Tonkin–Yunnan Trade Company',
            logo: '1881/TTC',
            simple_logo: '1881/TTC.alt',
            float_percent: 20,
            tokens: [0, 50, 80, 100],
            coordinates: 'B3',
            color: '#6aa84f',
            text_color: 'black',
          },
          {
            sym: 'TMR',
            name: 'Chemin de fer de Trans-Mékong',
            logo: '1881/TMR',
            simple_logo: '1881/TMR.alt',
            float_percent: 20,
            tokens: [0, 50, 80, 100],
            coordinates: 'D33',
            color: '#999999',
            text_color: 'black',
          },
          {
            sym: 'HPR',
            name: 'Chemin de fer de Hai Phong',
            logo: '1881/HPR',
            simple_logo: '1881/HPR.alt',
            float_percent: 20,
            tokens: [0, 50, 80, 100],
            coordinates: 'I6',
            color: '#6fa8dc',
            text_color: 'black',
          },
          {
            sym: 'AT',
            name: "Chemin de fer d'exportation de l'Arabica du Tonkin",
            logo: '1881/AT',
            simple_logo: '1881/AT.alt',
            float_percent: 20,
            tokens: [0, 50, 80, 100],
            coordinates: 'I28',
            color: '#7b4d12',
            text_color: 'white',
          },

          # === Minor corporations ===
          {
            sym: 'SFTC',
            name: 'Société Française des Charbonnages du Tonkin',
            logo: '1881/SFTC',
            simple_logo: '1881/SFTC.alt',
            shares: [50, 25, 25],
            share_percent: 25,
            float_percent: 20,
            tokens: [0, 50],
            coordinates: 'K4',
            color: '#000000',
            text_color: 'white',
          },
          {
            sym: 'CPA',
            name: "Compagnie des Pêcheries de l'Annam",
            logo: '1881/CPA',
            simple_logo: '1881/CPA.alt',
            float_percent: 20,
            tokens: [0, 50, 80, 100],
            coordinates: 'L29',
            color: '#0b5394',
            text_color: 'white',
          },
          {
            sym: 'FMT',
            name: 'Compagnie des Fruits de Mer du Tonkin',
            logo: '1881/FMT',
            simple_logo: '1881/FMT.alt',
            shares: [50, 25, 25],
            share_percent: 25,
            float_percent: 20,
            tokens: [0, 50],
            coordinates: 'C38',
            color: '#c8bfe7',
            text_color: 'black',
          },

          # === Doumer Fund ===
          # Represents the French state fund (after Governor-General Paul Doumer) that
          # bankrolled the Indochina railway program. Pars and floats automatically at
          # game start; never operates. See DOUMER_* constants in game.rb.
          {
            sym: 'DOUMER',
            name: "Fonds des chemins de fer de l'Indochine",
            logo: '1881/DOUMER',
            simple_logo: '1881/DOUMER.alt',
            shares: Array.new(10, 10),
            tokens: [0, 0, 100, 100, 100],
            color: '#14213d',
            text_color: 'white',
          },

          # === Việt Nam Railways (VNR) ===
          # Succeeds the Doumer Fund when it closes on phase 5+1 (see
          # event_doumer_fund_closes! and VNR_* constants in game.rb). A normal
          # operating corporation -- unlike the Doumer Fund -- but it needs 50%
          # of its shares sold before it floats, its treasury is a fixed seed
          # (plus whatever the Doumer Fund had accumulated from nationalized
          # corporations) rather than the usual per-share float proceeds, and
          # its capitalization is full so buying its shares never funds it.
          {
            sym: 'VNR',
            name: 'Việt Nam Railways',
            logo: '1881/DOUMER',
            simple_logo: '1881/DOUMER.alt',
            float_percent: 50,
            capitalization: 'full',
            tokens: [0, 0, 100, 100, 100],
            color: '#14213d',
            text_color: 'white',
          },
        ].freeze
      end
    end
  end
end
