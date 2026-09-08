# Catalog data stats

Generated. Re-run `python bin/catdb_era_stats.py`, or pack (`catdb_era_pack.py` / emit_base / emit_extra) which writes this file.

`Data/` is client CSV/DB2. `DataExtra/` is other warehouse sources.

## What loads

- **OneWoW_Catalog** — Catalog window plus query runtime (APIs, learned SavedVariables, Defer sinks). Era packs require Catalog so their tables have a home.
- **OneWoW_CatDB_Other** — same shape as an expansion pack, for rows with no expansion yet. Distro always ships it.
- **OneWoW_CatDB_<Expansion>** — the rows for that expansion.
- **OneWoW_CatDB_TradeSkillDB** — profession recipes (not split by expansion).

## Packs

```
  File                             rows       size
  -------------- ----------------------   --------
Midnight (1.2 MB)
  Hubs                                2     7.5 KB
  Zone               35 places / 61 enc      56 KB
  NPC                              1100     335 KB
  Quest                             408     100 KB
  Item                             8073     698 KB
  Achievement                        58     1.2 KB
  MapPin                              0      121 B
  ZoneExtra            0 places / 4 enc     7.0 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

TheWarWithin (1.6 MB)
  Hubs                                4     7.6 KB
  Zone               38 places / 76 enc      75 KB
  NPC                              1425     506 KB
  Quest                             478     120 KB
  Item                            10250     888 KB
  Achievement                        73     1.5 KB
  MapPin                              0      121 B
  ZoneExtra            0 places / 5 enc      11 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

Dragonflight (1.9 MB)
  Hubs                                2     9.0 KB
  Zone               20 places / 67 enc      80 KB
  NPC                              1655     633 KB
  Quest                             411     116 KB
  Item                            12978     1.1 MB
  Achievement                       196     3.8 KB
  MapPin                              0      121 B
  ZoneExtra           0 places / 11 enc      17 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

Shadowlands (1.6 MB)
  Hubs                                2      15 KB
  Zone               19 places / 82 enc      94 KB
  NPC                              1686     543 KB
  Quest                             577     137 KB
  Item                             9792     828 KB
  Achievement                        83     1.7 KB
  MapPin                              0      121 B
  ZoneExtra            0 places / 9 enc     6.6 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

BattleforAzeroth (2.0 MB)
  Hubs                                3      27 KB
  Zone               24 places / 97 enc      81 KB
  NPC                              2058     527 KB
  Quest                            1296     319 KB
  Item                            12860     1.1 MB
  Achievement                       143     2.8 KB
  MapPin                              0      121 B
  ZoneExtra           0 places / 10 enc     5.2 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

Legion (2.6 MB)
  Hubs                                3      17 KB
  Zone              27 places / 111 enc     110 KB
  NPC                              1796     647 KB
  Quest                            1180     302 KB
  Item                            17274     1.5 MB
  Achievement                        97     2.2 KB
  MapPin                              0      121 B
  ZoneExtra           0 places / 12 enc      15 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

WarlordsofDraenor (1.7 MB)
  Hubs                                3     6.7 KB
  Zone               18 places / 65 enc     150 KB
  NPC                              1769     595 KB
  Quest                              42     9.5 KB
  Item                            10781     984 KB
  Achievement                        42      888 B
  MapPin                              0      121 B
  ZoneExtra            0 places / 3 enc     5.4 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

MistsofPandaria (2.4 MB)
  Hubs                                1      84 KB
  Zone               22 places / 71 enc     119 KB
  NPC                              1291     504 KB
  Quest                             132      21 KB
  Item                            18664     1.7 MB
  Achievement                       155     2.9 KB
  MapPin                              0      121 B
  ZoneExtra           0 places / 12 enc      73 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

Cataclysm (1.2 MB)
  Hubs                                0      108 B
  Zone              30 places / 117 enc     153 KB
  NPC                               817     217 KB
  Quest                              22     4.8 KB
  Item                             8929     784 KB
  Achievement                        80     1.7 KB
  MapPin                              0      121 B
  ZoneExtra           0 places / 16 enc      15 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

WrathoftheLichKing (1.9 MB)
  Hubs                                1      338 B
  Zone              37 places / 135 enc     268 KB
  NPC                              1484     569 KB
  Quest                              49     6.0 KB
  Item                            12396     1.1 MB
  Achievement                        85     2.0 KB
  MapPin                              0      121 B
  ZoneExtra           0 places / 21 enc      38 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

BurningCrusade (1.2 MB)
  Hubs                                1      335 B
  Zone              33 places / 115 enc     117 KB
  NPC                               994     327 KB
  Quest                              50     7.6 KB
  Item                             8560     727 KB
  Achievement                       322     6.2 KB
  MapPin                              0      121 B
  ZoneExtra           0 places / 23 enc      19 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

Classic (5.6 MB)
  Hubs                                8     2.6 KB
  Zone             74 places / 1932 enc     495 KB
  NPC                              5776     1.6 MB
  Quest                             506      90 KB
  Item                            42589     3.3 MB
  Achievement                      1664      40 KB
  MapPin                              0      121 B
  ZoneExtra           0 places / 28 enc      46 KB
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

Other (606 KB)
  Hubs                                0      106 B
  Zone                                0      106 B
  NPC                                 0      104 B
  Quest                               0      108 B
  Item                             6856     603 KB
  Achievement                        65     1.6 KB
  MapPin                              0      121 B
  ZoneExtra                           0      118 B
  NpcExtra                            0      110 B
  QuestExtra                          0      114 B
  ItemExtra                           0      112 B

Tradeskills (3.3 MB)
  Alchemy                           925     280 KB
  Blacksmithing                    1699     469 KB
  Cooking                           651     173 KB
  Enchanting                       1022     294 KB
  Engineering                      1021     330 KB
  Fishing                           123      20 KB
  Herbalism                         220      41 KB
  HousingDyes                        93      19 KB
  Inscription                       971     305 KB
  Jewelcrafting                    1476     412 KB
  Leatherworking                   1925     544 KB
  Mining                            222      45 KB
  Skinning                          130      26 KB
  Tailoring                        1373     389 KB
  Total recipes                   11851     3.3 MB
```
