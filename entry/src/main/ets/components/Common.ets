/**
 * 通用组件 —— 等级头卡 / 游戏卡 / 连胜火焰 / 筛选条 / 统计胶囊
 *
 * 全部从 Design.ets 取数值，**组件里不出现魔法数字**。
 * 动效一律走 Motion 的时长，按下必有 0.96 缩放反馈。
 */

import { Bp } from '../core/Bp';
import { Tv } from '../core/Tv';
import { Haptics } from '../core/Haptics';
import { Digits } from '../core/I18n';   // ★ 2026-10-16 数字本地化
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Overlay, Accent, Cell } from '../core/Design';
import { GameMeta, GameCategory, CatCount, colorOf, enterDelay, catLabelEn, ACCENT_TAG, ACCENT_DEEP_TAG, displayName, displayTagline } from '../core/GameRegistry';
import { L, TN } from '../core/I18n';

// ─── ICON_MAP:BEGIN（由 tools/gen_icon_map.py 生成，勿手改）───
/**
 * 游戏图标资源表（354 款，每款一张预渲染位图）。
 *
 * 图标由 `tools/gen_game_icons.py` 生成到 `resources/base/media/gico_<id>.png`：
 *   · 改前 354 款共用 69 个 emoji（327 款跟别人撞脸）
 *   · 改后每款一张 192px 位图，感知哈希 354/354 互不相同
 * 这里是**字面量**表（不是 `$r('app.media.' + id)`）：
 * `$r()` 走编译期解析，拼出来的字符串没法保证在真机上能解析。
 */
const ICON_MAP: Record<string, Resource> = {
  'bejeweled': $r('app.media.gico_bejeweled'),
  'breakout': $r('app.media.gico_breakout'),
  'bubble_shooter': $r('app.media.gico_bubble_shooter'),
  'checkers': $r('app.media.gico_checkers'),
  'compound_connect': $r('app.media.gico_compound_connect'),
  'connect_four': $r('app.media.gico_connect_four'),
  'continuous_paired_associate': $r('app.media.gico_continuous_paired_associate'),
  'doodle_jump': $r('app.media.gico_doodle_jump'),
  'double_trouble': $r('app.media.gico_double_trouble'),
  'dual_mirror': $r('app.media.gico_dual_mirror'),
  'flappy': $r('app.media.gico_flappy'),
  'freecell': $r('app.media.gico_freecell'),
  'g2048': $r('app.media.gico_g2048'),
  'game24': $r('app.media.gico_game24'),
  'go9': $r('app.media.gico_go9'),
  'gomoku': $r('app.media.gico_gomoku'),
  'hanoi': $r('app.media.gico_hanoi'),
  'kakuro_mini': $r('app.media.gico_kakuro_mini'),
  'life_game': $r('app.media.gico_life_game'),
  'lock_pattern': $r('app.media.gico_lock_pattern'),
  'mahjong_solitaire': $r('app.media.gico_mahjong_solitaire'),
  'mancala': $r('app.media.gico_mancala'),
  'mandelbrot': $r('app.media.gico_mandelbrot'),
  'mastermind': $r('app.media.gico_mastermind'),
  'match3': $r('app.media.gico_match3'),
  'memory': $r('app.media.gico_memory'),
  'minesweeper': $r('app.media.gico_minesweeper'),
  'nim': $r('app.media.gico_nim'),
  'peg_solitaire': $r('app.media.gico_peg_solitaire'),
  'phonetic_guess': $r('app.media.gico_phonetic_guess'),
  'pong': $r('app.media.gico_pong'),
  'reversi': $r('app.media.gico_reversi'),
  'schulte': $r('app.media.gico_schulte'),
  'sieve_visualizer': $r('app.media.gico_sieve_visualizer'),
  'simon_says': $r('app.media.gico_simon_says'),
  'slide15': $r('app.media.gico_slide15'),
  'snake': $r('app.media.gico_snake'),
  'snake_3d': $r('app.media.gico_snake_3d'),
  'sokoban': $r('app.media.gico_sokoban'),
  'solitaire': $r('app.media.gico_solitaire'),
  'sorting_visualizer': $r('app.media.gico_sorting_visualizer'),
  'spider_solitaire': $r('app.media.gico_spider_solitaire'),
  'sudoku_hex': $r('app.media.gico_sudoku_hex'),
  'tetris': $r('app.media.gico_tetris'),
  'tic_tac_toe': $r('app.media.gico_tic_tac_toe'),
  'wordle': $r('app.media.gico_wordle'),
  'akari': $r('app.media.gico_akari'),
  'alphabet_sudoku': $r('app.media.gico_alphabet_sudoku'),
  'binary_puzzle': $r('app.media.gico_binary_puzzle'),
  'block_escape': $r('app.media.gico_block_escape'),
  'bridges': $r('app.media.gico_bridges'),
  'bridges_all': $r('app.media.gico_bridges_all'),
  'color_flood': $r('app.media.gico_color_flood'),
  'crown': $r('app.media.gico_crown'),
  'dominosa': $r('app.media.gico_dominosa'),
  'fillomino': $r('app.media.gico_fillomino'),
  'futoshiki': $r('app.media.gico_futoshiki'),
  'gokigen_naname': $r('app.media.gico_gokigen_naname'),
  'heyawake': $r('app.media.gico_heyawake'),
  'hitori': $r('app.media.gico_hitori'),
  'hitori_all': $r('app.media.gico_hitori_all'),
  'kakurasu_sums': $r('app.media.gico_kakurasu_sums'),
  'kakuro': $r('app.media.gico_kakuro'),
  'kenken': $r('app.media.gico_kenken'),
  'klotski': $r('app.media.gico_klotski'),
  'kurodoko': $r('app.media.gico_kurodoko'),
  'lighthouses': $r('app.media.gico_lighthouses'),
  'lights_out': $r('app.media.gico_lights_out'),
  'magnets': $r('app.media.gico_magnets'),
  'masyu': $r('app.media.gico_masyu'),
  'math_maze': $r('app.media.gico_math_maze'),
  'math_path': $r('app.media.gico_math_path'),
  'nonogram': $r('app.media.gico_nonogram'),
  'norinori': $r('app.media.gico_norinori'),
  'nurikabe': $r('app.media.gico_nurikabe'),
  'path_finder': $r('app.media.gico_path_finder'),
  'path_intersect': $r('app.media.gico_path_intersect'),
  'pipes': $r('app.media.gico_pipes'),
  'shikaku': $r('app.media.gico_shikaku'),
  'skyscrapers': $r('app.media.gico_skyscrapers'),
  'slide_puzzle': $r('app.media.gico_slide_puzzle'),
  'slitherlink': $r('app.media.gico_slitherlink'),
  'sudoku': $r('app.media.gico_sudoku'),
  'sum_snake': $r('app.media.gico_sum_snake'),
  'tangle_fix': $r('app.media.gico_tangle_fix'),
  'tapa': $r('app.media.gico_tapa'),
  'tenner_grid': $r('app.media.gico_tenner_grid'),
  'tents_and_trees': $r('app.media.gico_tents_and_trees'),
  'water_sort': $r('app.media.gico_water_sort'),
  'yajilin': $r('app.media.gico_yajilin'),
  'algebraic_balance': $r('app.media.gico_algebraic_balance'),
  'algebraic_inequality_solver': $r('app.media.gico_algebraic_inequality_solver'),
  'arithmetic_chain': $r('app.media.gico_arithmetic_chain'),
  'balance_scale': $r('app.media.gico_balance_scale'),
  'base_conversion_run': $r('app.media.gico_base_conversion_run'),
  'base_shift': $r('app.media.gico_base_shift'),
  'binary_code': $r('app.media.gico_binary_code'),
  'binary_matrix_rank': $r('app.media.gico_binary_matrix_rank'),
  'binary_scale_balance': $r('app.media.gico_binary_scale_balance'),
  'binomial_match': $r('app.media.gico_binomial_match'),
  'calculation_sprint': $r('app.media.gico_calculation_sprint'),
  'collatz': $r('app.media.gico_collatz'),
  'common_denominator': $r('app.media.gico_common_denominator'),
  'countdown_math': $r('app.media.gico_countdown_math'),
  'crypto_arithmetic': $r('app.media.gico_crypto_arithmetic'),
  'digit_swap_eq': $r('app.media.gico_digit_swap_eq'),
  'divisibility_dash': $r('app.media.gico_divisibility_dash'),
  'exponent_tower': $r('app.media.gico_exponent_tower'),
  'factor_finder': $r('app.media.gico_factor_finder'),
  'fibonacci_merge': $r('app.media.gico_fibonacci_merge'),
  'fraction_match': $r('app.media.gico_fraction_match'),
  'fraction_matcher': $r('app.media.gico_fraction_matcher'),
  'fractional_pizza': $r('app.media.gico_fractional_pizza'),
  'inequality_balance_ops': $r('app.media.gico_inequality_balance_ops'),
  'inequality_dash': $r('app.media.gico_inequality_dash'),
  'magic_squares': $r('app.media.gico_magic_squares'),
  'matrix_multiplier': $r('app.media.gico_matrix_multiplier'),
  'matrix_multiplier_match': $r('app.media.gico_matrix_multiplier_match'),
  'matrix_reasoning': $r('app.media.gico_matrix_reasoning'),
  'mental_abacus': $r('app.media.gico_mental_abacus'),
  'mental_calendar': $r('app.media.gico_mental_calendar'),
  'missing_operator': $r('app.media.gico_missing_operator'),
  'modular_clock_arithmetic': $r('app.media.gico_modular_clock_arithmetic'),
  'modulo_clock': $r('app.media.gico_modulo_clock'),
  'modulo_path': $r('app.media.gico_modulo_path'),
  'number_bonds': $r('app.media.gico_number_bonds'),
  'number_bonds_all': $r('app.media.gico_number_bonds_all'),
  'numerical_estimation': $r('app.media.gico_numerical_estimation'),
  'pattern_sequence_draw': $r('app.media.gico_pattern_sequence_draw'),
  'percentage_peak': $r('app.media.gico_percentage_peak'),
  'percentage_shopping': $r('app.media.gico_percentage_shopping'),
  'prime_factor_trees': $r('app.media.gico_prime_factor_trees'),
  'prime_gap_hunt': $r('app.media.gico_prime_gap_hunt'),
  'prime_hunter': $r('app.media.gico_prime_hunter'),
  'pythagorean_triple_builder': $r('app.media.gico_pythagorean_triple_builder'),
  'quick_math': $r('app.media.gico_quick_math'),
  'radical_roots': $r('app.media.gico_radical_roots'),
  'roman_arithmetic': $r('app.media.gico_roman_arithmetic'),
  'sequence_sleuth': $r('app.media.gico_sequence_sleuth'),
  'sequence_stack': $r('app.media.gico_sequence_stack'),
  'set_theory_venn': $r('app.media.gico_set_theory_venn'),
  'sum_pyramid': $r('app.media.gico_sum_pyramid'),
  'target_10': $r('app.media.gico_target_10'),
  'target_number': $r('app.media.gico_target_number'),
  'unit_converter_pro': $r('app.media.gico_unit_converter_pro'),
  'vector_dot_product': $r('app.media.gico_vector_dot_product'),
  'vector_grid_alignment': $r('app.media.gico_vector_grid_alignment'),
  'vektor_vector': $r('app.media.gico_vektor_vector'),
  'venn_numbers': $r('app.media.gico_venn_numbers'),
  'associative_pairs': $r('app.media.gico_associative_pairs'),
  'attentional_blink': $r('app.media.gico_attentional_blink'),
  'attentional_blink_probe': $r('app.media.gico_attentional_blink_probe'),
  'card_counting_memory': $r('app.media.gico_card_counting_memory'),
  'change_blindness': $r('app.media.gico_change_blindness'),
  'choice_reaction_time': $r('app.media.gico_choice_reaction_time'),
  'color_word_match_up': $r('app.media.gico_color_word_match_up'),
  'conjunction_search': $r('app.media.gico_conjunction_search'),
  'continuous_recognition': $r('app.media.gico_continuous_recognition'),
  'corsi_backward_span': $r('app.media.gico_corsi_backward_span'),
  'corsi_blocks': $r('app.media.gico_corsi_blocks'),
  'counting_span': $r('app.media.gico_counting_span'),
  'd2_attention': $r('app.media.gico_d2_attention'),
  'delayed_match_sample': $r('app.media.gico_delayed_match_sample'),
  'digit_span_reverse': $r('app.media.gico_digit_span_reverse'),
  'divided_attention': $r('app.media.gico_divided_attention'),
  'dnms': $r('app.media.gico_dnms'),
  'double_n_back': $r('app.media.gico_double_n_back'),
  'dual_coding': $r('app.media.gico_dual_coding'),
  'dual_task_memory': $r('app.media.gico_dual_task_memory'),
  'dynamic_salience': $r('app.media.gico_dynamic_salience'),
  'event_timeline_memory': $r('app.media.gico_event_timeline_memory'),
  'face_name_association': $r('app.media.gico_face_name_association'),
  'face_trait_association': $r('app.media.gico_face_trait_association'),
  'feature_matrix_recall': $r('app.media.gico_feature_matrix_recall'),
  'feature_matrix_recall_all': $r('app.media.gico_feature_matrix_recall_all'),
  'flanker_test': $r('app.media.gico_flanker_test'),
  'frequency_tap': $r('app.media.gico_frequency_tap'),
  'ghost_tap': $r('app.media.gico_ghost_tap'),
  'go_no_go': $r('app.media.gico_go_no_go'),
  'grocery_list': $r('app.media.gico_grocery_list'),
  'mandala_recall': $r('app.media.gico_mandala_recall'),
  'memory_matrix': $r('app.media.gico_memory_matrix'),
  'memory_palace': $r('app.media.gico_memory_palace'),
  'multiple_object_tracking': $r('app.media.gico_multiple_object_tracking'),
  'n_back': $r('app.media.gico_n_back'),
  'narrative_recall': $r('app.media.gico_narrative_recall'),
  'negative_space_detection': $r('app.media.gico_negative_space_detection'),
  'object_displacement': $r('app.media.gico_object_displacement'),
  'object_shuffle': $r('app.media.gico_object_shuffle'),
  'odd_even_flash': $r('app.media.gico_odd_even_flash'),
  'operation_span': $r('app.media.gico_operation_span'),
  'peripheral_focus': $r('app.media.gico_peripheral_focus'),
  'posner_spatial_cueing': $r('app.media.gico_posner_spatial_cueing'),
  'probe_digit_span': $r('app.media.gico_probe_digit_span'),
  'reading_span': $r('app.media.gico_reading_span'),
  'reflex_tap': $r('app.media.gico_reflex_tap'),
  'relational_memory': $r('app.media.gico_relational_memory'),
  'reverse_stroop': $r('app.media.gico_reverse_stroop'),
  'rhythm_master': $r('app.media.gico_rhythm_master'),
  'rule_switcher': $r('app.media.gico_rule_switcher'),
  'running_memory_span': $r('app.media.gico_running_memory_span'),
  'sdmt': $r('app.media.gico_sdmt'),
  'shell_game': $r('app.media.gico_shell_game'),
  'sopt': $r('app.media.gico_sopt'),
  'spatial_cabinet_memory': $r('app.media.gico_spatial_cabinet_memory'),
  'spotlight_track': $r('app.media.gico_spotlight_track'),
  'staircase_memory': $r('app.media.gico_staircase_memory'),
  'stop_signal': $r('app.media.gico_stop_signal'),
  'stroop_number_size': $r('app.media.gico_stroop_number_size'),
  'stroop_test': $r('app.media.gico_stroop_test'),
  'subitizing_rush': $r('app.media.gico_subitizing_rush'),
  'switch_task': $r('app.media.gico_switch_task'),
  'symbol_digit_assoc': $r('app.media.gico_symbol_digit_assoc'),
  'symbol_logic': $r('app.media.gico_symbol_logic'),
  'symbolic_flanker': $r('app.media.gico_symbolic_flanker'),
  'task_switching': $r('app.media.gico_task_switching'),
  'trail_making': $r('app.media.gico_trail_making'),
  'vigilance_task': $r('app.media.gico_vigilance_task'),
  'visual_crowding_acuity': $r('app.media.gico_visual_crowding_acuity'),
  'visual_search': $r('app.media.gico_visual_search'),
  'visual_search_conjunction': $r('app.media.gico_visual_search_conjunction'),
  'wisconsin_card_sorting': $r('app.media.gico_wisconsin_card_sorting'),
  'word_pair_associate_memory': $r('app.media.gico_word_pair_associate_memory'),
  'affix_factory': $r('app.media.gico_affix_factory'),
  'anagram_definition': $r('app.media.gico_anagram_definition'),
  'category_fluency': $r('app.media.gico_category_fluency'),
  'chalk_and_talk': $r('app.media.gico_chalk_and_talk'),
  'chimp_test': $r('app.media.gico_chimp_test'),
  'cognate_catch': $r('app.media.gico_cognate_catch'),
  'consonant_reconstruct': $r('app.media.gico_consonant_reconstruct'),
  'context_clues': $r('app.media.gico_context_clues'),
  'conundrum_anagram': $r('app.media.gico_conundrum_anagram'),
  'crossword': $r('app.media.gico_crossword'),
  'cryptogram': $r('app.media.gico_cryptogram'),
  'definition_dash': $r('app.media.gico_definition_dash'),
  'etymology_origin': $r('app.media.gico_etymology_origin'),
  'etymon_oddball': $r('app.media.gico_etymon_oddball'),
  'find_word': $r('app.media.gico_find_word'),
  'grammar_police': $r('app.media.gico_grammar_police'),
  'grammar_sort': $r('app.media.gico_grammar_sort'),
  'homophone_hunt': $r('app.media.gico_homophone_hunt'),
  'letter_bridge': $r('app.media.gico_letter_bridge'),
  'letter_cancellation': $r('app.media.gico_letter_cancellation'),
  'letter_frequency_scan': $r('app.media.gico_letter_frequency_scan'),
  'letter_grid_swapper': $r('app.media.gico_letter_grid_swapper'),
  'missing_vowels': $r('app.media.gico_missing_vowels'),
  'one_letter_shift': $r('app.media.gico_one_letter_shift'),
  'oxymoron_hunt': $r('app.media.gico_oxymoron_hunt'),
  'palindrome_builder': $r('app.media.gico_palindrome_builder'),
  'pangram_sprint': $r('app.media.gico_pangram_sprint'),
  'portmanteau_split': $r('app.media.gico_portmanteau_split'),
  'rhyme_master': $r('app.media.gico_rhyme_master'),
  'semantic_association': $r('app.media.gico_semantic_association'),
  'semantic_distance': $r('app.media.gico_semantic_distance'),
  'semantic_link': $r('app.media.gico_semantic_link'),
  'sentence_unscramble': $r('app.media.gico_sentence_unscramble'),
  'silent_letter_search': $r('app.media.gico_silent_letter_search'),
  'spelling_sprint': $r('app.media.gico_spelling_sprint'),
  'spoonerism_solver': $r('app.media.gico_spoonerism_solver'),
  'story_builder': $r('app.media.gico_story_builder'),
  'syllable_stack': $r('app.media.gico_syllable_stack'),
  'typing_speed': $r('app.media.gico_typing_speed'),
  'typoglycemia_decoder': $r('app.media.gico_typoglycemia_decoder'),
  'verbal_analogies': $r('app.media.gico_verbal_analogies'),
  'vocabulary_builder': $r('app.media.gico_vocabulary_builder'),
  'vowel_reconstruct': $r('app.media.gico_vowel_reconstruct'),
  'word_association_recall': $r('app.media.gico_word_association_recall'),
  'word_grid_connection': $r('app.media.gico_word_grid_connection'),
  'word_ladder': $r('app.media.gico_word_ladder'),
  'word_ladder_step': $r('app.media.gico_word_ladder_step'),
  'word_mastermind': $r('app.media.gico_word_mastermind'),
  'word_scramble': $r('app.media.gico_word_scramble'),
  'word_search': $r('app.media.gico_word_search'),
  'word_snake_trail': $r('app.media.gico_word_snake_trail'),
  'word_surge': $r('app.media.gico_word_surge'),
  'word_wheel': $r('app.media.gico_word_wheel'),
  'ab_reversal_oddball': $r('app.media.gico_ab_reversal_oddball'),
  'action_sequence_recall': $r('app.media.gico_action_sequence_recall'),
  'angle_finder': $r('app.media.gico_angle_finder'),
  'area_perimeter_match': $r('app.media.gico_area_perimeter_match'),
  'binary_matrix_rank_all': $r('app.media.gico_binary_matrix_rank_all'),
  'blink_detector': $r('app.media.gico_blink_detector'),
  'block_count_3d': $r('app.media.gico_block_count_3d'),
  'block_stacking_physics': $r('app.media.gico_block_stacking_physics'),
  'box_completion': $r('app.media.gico_box_completion'),
  'chain_reaction': $r('app.media.gico_chain_reaction'),
  'circuit_connect': $r('app.media.gico_circuit_connect'),
  'classic_maze': $r('app.media.gico_classic_maze'),
  'color_match': $r('app.media.gico_color_match'),
  'color_maze_nav': $r('app.media.gico_color_maze_nav'),
  'compass_maze': $r('app.media.gico_compass_maze'),
  'complex_folding_nets': $r('app.media.gico_complex_folding_nets'),
  'counting_sheep': $r('app.media.gico_counting_sheep'),
  'cross_section_slice': $r('app.media.gico_cross_section_slice'),
  'cryptogram_all': $r('app.media.gico_cryptogram_all'),
  'cube_net_fold': $r('app.media.gico_cube_net_fold'),
  'directions_recall': $r('app.media.gico_directions_recall'),
  'distractor_matrix': $r('app.media.gico_distractor_matrix'),
  'einstein_riddle': $r('app.media.gico_einstein_riddle'),
  'fact_binder': $r('app.media.gico_fact_binder'),
  'focus_tunnel': $r('app.media.gico_focus_tunnel'),
  'gear_rotation': $r('app.media.gico_gear_rotation'),
  'gear_train_direction': $r('app.media.gico_gear_train_direction'),
  'geometric_vision': $r('app.media.gico_geometric_vision'),
  'graph_coordinate_plot': $r('app.media.gico_graph_coordinate_plot'),
  'gravity_sort': $r('app.media.gico_gravity_sort'),
  'grid_displacement': $r('app.media.gico_grid_displacement'),
  'hue_sort': $r('app.media.gico_hue_sort'),
  'interlock_puzzle': $r('app.media.gico_interlock_puzzle'),
  'laser_link': $r('app.media.gico_laser_link'),
  'laser_reflect': $r('app.media.gico_laser_reflect'),
  'logical_syllogisms': $r('app.media.gico_logical_syllogisms'),
  'math_guess': $r('app.media.gico_math_guess'),
  'maze_nav_3d': $r('app.media.gico_maze_nav_3d'),
  'mental_mapping': $r('app.media.gico_mental_mapping'),
  'mental_rotation': $r('app.media.gico_mental_rotation'),
  'mirror_image': $r('app.media.gico_mirror_image'),
  'mirror_maze': $r('app.media.gico_mirror_maze'),
  'mirror_tracing': $r('app.media.gico_mirror_tracing'),
  'multi_track_counter': $r('app.media.gico_multi_track_counter'),
  'navon_hierarchical': $r('app.media.gico_navon_hierarchical'),
  'odd_one_out': $r('app.media.gico_odd_one_out'),
  'odd_rotation': $r('app.media.gico_odd_rotation'),
  'orbit_tap': $r('app.media.gico_orbit_tap'),
  'paper_folding': $r('app.media.gico_paper_folding'),
  'path_recall': $r('app.media.gico_path_recall'),
  'perspective_shift_view': $r('app.media.gico_perspective_shift_view'),
  'perspective_taking': $r('app.media.gico_perspective_taking'),
  'pixel_mimic': $r('app.media.gico_pixel_mimic'),
  'polyomino_tiling': $r('app.media.gico_polyomino_tiling'),
  'room_inspector': $r('app.media.gico_room_inspector'),
  'rotating_maze': $r('app.media.gico_rotating_maze'),
  'shadow_pivot': $r('app.media.gico_shadow_pivot'),
  'shape_shifter': $r('app.media.gico_shape_shifter'),
  'silhouette_match': $r('app.media.gico_silhouette_match'),
  'silhouette_match_ortho': $r('app.media.gico_silhouette_match_ortho'),
  'simon_command': $r('app.media.gico_simon_command'),
  'simon_sequence': $r('app.media.gico_simon_sequence'),
  'source_monitoring': $r('app.media.gico_source_monitoring'),
  'spatial_conflict': $r('app.media.gico_spatial_conflict'),
  'sternberg_task': $r('app.media.gico_sternberg_task'),
  'symmetry': $r('app.media.gico_symmetry'),
  'symmetry_span': $r('app.media.gico_symmetry_span'),
  'tangram': $r('app.media.gico_tangram'),
  'temporal_order': $r('app.media.gico_temporal_order'),
  'temporal_order_judgment': $r('app.media.gico_temporal_order_judgment'),
  'topology': $r('app.media.gico_topology'),
  'tower_of_hanoi': $r('app.media.gico_tower_of_hanoi'),
  'tower_of_london': $r('app.media.gico_tower_of_london'),
  'trace_path': $r('app.media.gico_trace_path'),
  'triple_sequence': $r('app.media.gico_triple_sequence'),
  'triplets_logic': $r('app.media.gico_triplets_logic'),
  'visual_search_all': $r('app.media.gico_visual_search_all'),
  'visual_statistical_learning': $r('app.media.gico_visual_statistical_learning'),
  'wireframe_3d_rotation': $r('app.media.gico_wireframe_3d_rotation'),
};

/** 取某款游戏的图标资源；查不到返回 undefined（调用方自己兜底） */
export function iconOf(id: string): Resource | undefined {
  return ICON_MAP[id];
}

/**
 * ★ 按 id 记忆化卡片底色
 *
 * ⚠️ 本块依赖 `ACCENT_TAG` / `ACCENT_DEEP_TAG`（来自 GameRegistry）—— 别删那两个 import。
 *
 * `colorOf(this.meta)` 每次返回同一个字符串，`@Prop` 值比较不会触发重渲染；
 * 但它在 build 里被调 354 次、每次进一次函数调用。这里用一张表降到一次查表，
 * 顺带保证**同一款游戏永远拿到同一个字符串**（ArkUI 的 @Prop 才认"没变"）。
 */
const CARD_COLOR: Record<string, string> = {};

export function cardColorOf(g: GameMeta): string {
  // ★ 2026-10-13（P5 · i18n-theme 加，勿删）：59 款"跟随主题色"的卡片**不能进缓存** ——
  //   缓存会把主题色冻在第一次取色的那一刻，用户改色后它们永远是旧色。
  if (g.color === ACCENT_TAG || g.color === ACCENT_DEEP_TAG) {
    return colorOf(g);
  }
  const hit: string | undefined = CARD_COLOR[g.id];
  if (hit !== undefined) {
    return hit;
  }
  const c: string = colorOf(g);
  CARD_COLOR[g.id] = c;
  return c;
}
// ─── ICON_MAP:END ───

/** ───────────── 连胜火焰 ───────────── */
@Component
export struct StreakFlame {
  @Prop streak: number = 0;
  @Prop theme: Theme = Theme.light();
  @State pulse: number = 1;
  /** ★ 2026-10-13（P4）：语言依赖 —— 只调 TN() 不读 langCode 的话，换语言这行不会重建 */
  @StorageProp('lang') langCode: string = 'zh';

  private tn(zh: string, en: string, n: number, f1?: string, f2?: string, f5?: string): string {
    const observed: string = this.langCode;
    return TN(zh, en, n, f1, f2, f5);   // ★ 复数透传（不传则退回旧行为）
  }

  aboutToAppear(): void {
    if (this.streak > 0) {
      // 连续缩放脉冲：1.0 ↔ 1.08，1200ms 一轮
      animateTo({
        duration: 1200,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate
      }, () => {
        this.pulse = 1.08;
      });
    }
  }

  build() {
    Row({ space: Space.xs }) {
      Text('🔥')
        .accessibilityLevel('no')
        .fontSize(FontSize.lg)
        .scale({ x: this.pulse, y: this.pulse })
      Text(this.tn('{n} 天', '{n} days', this.streak, '{n} день', '{n} дня', '{n} дней'))
        .fontSize(FontSize.sm)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.streak > 0 ? Palette.orange : this.theme.inkFaint)
    }
    .padding({ left: Space.sm, right: Space.sm, top: Space.xs, bottom: Space.xs })
    .backgroundColor(this.streak > 0 ? '#1AF59E0B' : this.theme.surfaceAlt)
    .borderRadius(Radius.full)
  }
}

/** ───────────── 等级头卡 ───────────── */
@Component
export struct LevelHeader {
  @StorageProp('xp') xp: number = 0;
  @StorageProp('level') level: number = 1;
  @StorageProp('superStreak') streak: number = 0;
  @StorageProp('solvedToday') solvedToday: boolean = false;
  @StorageProp('totalSolved') totalSolved: number = 0;
  // ★ 2026-10-13（P4/P5）：等级称号、进度文案、打卡文案都要跟语言；徽章/进度条要跟主题色
  @StorageProp('lang') langCode: string = 'zh';
  @StorageProp('accent') accentId: string = Palette.primary;
  @Prop theme: Theme = Theme.light();

  /** 取当前语言的文案（读一次 langCode 建立 ArkUI 依赖） */
  private t(zh: string, en: string): string {
    const observed: string = this.langCode;
    return L(zh, en);
  }

  /** 带数字的整句模板（语序随语言变，别在调用点拼片段） */
  private tn(zh: string, en: string, n: number, f1?: string, f2?: string, f5?: string): string {
    const observed: string = this.langCode;
    return TN(zh, en, n, f1, f2, f5);   // ★ 复数透传（不传则退回旧行为）
  }

  /** 当前主题色（id 可能是 'system'，一律走 Accent 解析） */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  /** 当前等级内进度 */
  private progress(): number {
    const lo: number = this.level <= 1 ? 0 : Math.floor(100 * Math.pow(this.level - 1, 2.04));
    const hi: number = Math.floor(100 * Math.pow(this.level, 2.04));
    if (hi <= lo) {
      return 1;
    }
    const p: number = (this.xp - lo) / (hi - lo);
    return Math.min(1, Math.max(0, p));
  }

  private toNext(): number {
    const hi: number = Math.floor(100 * Math.pow(this.level, 2.04));
    return Math.max(0, hi - this.xp);
  }

  build() {
    Column({ space: Space.md }) {
      Row() {
        // 等级徽章
        Stack() {
          Circle({ width: 56, height: 56 })
            .fill(this.accentColor())
            .shadow(Shadow.card)
          Column() {
            Text('LV').fontSize(FontSize.xxs).fontColor(Overlay.onColorSoft)
            Text(Digits(String(this.level), this.langCode))
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
        }
        .width(Cell.of(56)).height(Cell.of(56))

        Column({ space: Space.xs }) {
          Text(this.titleForLevel())
            .fontSize(FontSize.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ink)
          Text(this.tn('通关 {n} 局', 'Cleared {n}', this.totalSolved))
            .fontSize(FontSize.xs)
            .fontColor(this.theme.inkFaint)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: Space.md })

        StreakFlame({ streak: this.streak, theme: this.theme })
      }
      .width('100%')

      // XP 进度条
      Column({ space: Space.xs }) {
        Row() {
          Text(this.tn('再攒 {n} 点经验就升级', '{n} XP to next level', this.toNext()))
            .fontSize(FontSize.xxs)
            .fontColor(this.theme.inkFaint)
          Blank()
          // ★★★ 2026-10-16 BUG #25 收尾：统计页/游戏页顶部的百分比是【这个共用组件】画的
        //   （我在 StatsTab 里改的是另一处 ⇒ 实拍不变 ⇒ 靠「代码对但界面不变」定位到真凶）
        Text(Digits(String(Math.round(this.progress() * 100)), this.langCode) + '%')
            .fontSize(FontSize.xxs)
            .fontColor(this.accentColor())
            .fontWeight(FontWeight.Bold)
        }
        .width('100%')

        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%').height(8)
            .backgroundColor(this.theme.line)
            .borderRadius(Radius.full)
          Row()
            .width((this.progress() * 100) + '%')
            .height(8)
            .backgroundColor(this.accentColor())
            .borderRadius(Radius.full)
            .animation({ duration: Motion.slow, curve: Motion.spring() })
        }
        .width('100%').height(8)
      }
      .width('100%')

      // 今日打卡状态
      Row({ space: Space.xs }) {
        Text(this.solvedToday ? '✅' : '⭕')
          .fontSize(FontSize.md)
        Text(this.solvedToday ? this.t('今日已打卡', 'Checked in today')
                              : this.t('还没玩 · 来一局就打卡', 'Not yet — play one round'))
          .fontSize(FontSize.xs)
          .fontColor(this.solvedToday ? Palette.emerald : this.theme.inkSoft)
      }
      .width('100%')
      .padding(Space.sm)
      .backgroundColor(this.solvedToday ? '#1410B981' : this.theme.surfaceAlt)
      .borderRadius(Radius.sm)
    }
    .width('100%')
    .padding(Space.lg)
    .backgroundColor(this.theme.surface)
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
  }

  private titleForLevel(): string {
    const l: number = this.level;
    if (l >= 60) {
      return this.t('游戏宗师', 'Grandmaster');
    }
    if (l >= 40) {
      return this.t('解谜高手', 'Puzzle Master');
    }
    if (l >= 25) {
      return this.t('益智达人', 'Puzzle Pro');
    }
    if (l >= 15) {
      return this.t('小有所成', 'Getting Somewhere');
    }
    if (l >= 8) {
      return this.t('渐入佳境', 'In the Groove');
    }
    if (l >= 3) {
      return this.t('初窥门径', 'First Steps');
    }
    return this.t('新手上路', 'Newcomer');
  }
}

/** ───────────── 游戏卡 ───────────── */
@Component
export struct GameCard {
  @Prop meta: GameMeta;
  // ★ 必须自己观察语言：ArkUI 只认 @State/@Prop/@StorageProp 的读取，
  //   光调 displayName()（读静态字段）不会让这张卡重渲染
  @StorageProp('lang') langCode: string = 'zh';
  /**
   * ★ 2026-10-13（P5 · 模拟器实测）：卡片自己**必须**观察 accent ——
   *   原来只调 `cardColorOf(meta)`：设置页改色后外层 GamesTab 会重绘，
   *   但 GameCard 的 `@Prop meta` 没变 ⇒ ArkUI 跳过这张卡的重建 ⇒
   *   59 款"跟随主题色"的卡片一直停在旧色（实测：点红后「宝石迷阵」仍是靛蓝 #6466F1）。
   */
  @StorageProp('accent') accentId: string = Palette.primary;
  /**
   * ★★★ 2026-10-16 实拍【德语 × 大字模式】抓到观感问题：
   *   大字模式下德语游戏名只剩 4 个字（「Bejeweled」→「Beje…」「Breakout」→「Bre…」）
   *   ★ 大字模式本来就是【给看不清的人用的】—— 名字只剩 4 个字 = 这模式失去意义
   *   ⇒ 修：大字模式允许【两行】显示名字；默认/简约仍一行 + 省略号
   *   ★ 必须自己观察 uiMode（ArkUI 只认 @State/@Prop/@StorageProp 的读取，同 lang/accent）
   */
  @StorageProp('uiMode') uiMode: string = 'normal';
  @Prop index: number = 0;
  @Prop theme: Theme = Theme.light();
  @Prop streak: number = 0;
  @Prop playedToday: boolean = false;
  /**
   * 共享元素转场 id（动画 ①）—— 非空时这张卡参与 `geometryTransition` 补间。
   * 默认空串 = 不参与；GamesTab 只在"正在点开的那一张"上传入。
   */
  @Prop sharedId: string = '';
  onOpen: (id: string) => void = () => {};
  /** 长按 = 收藏 / 取消收藏 */
  onLongPress: (id: string) => void = () => {};

  @State private pressed: boolean = false;
  // ★★★ 2026-10-14 奥森反馈「滑动时游戏还是闪现」⇒ 第三处根因修：
  //   原来是 `shown = false` ⇒ ArkUI 时序是【@State 初值(false) → aboutToAppear → build】
  //   ⇒ ★ 每张滚动中新建的卡片【第一帧就是 opacity 0 + 下移16】⇒ 然后才变可见 = 闪一下
  //   修法：初值改 true（★ 默认就是可见的）；只有【该做错峰进场的首屏卡片】
  //        才在 aboutToAppear 里先压成 false，再按 delay 亮起。
  @State private shown: boolean = true;
  // ★★★ 2026-10-14 闪现第 6 层：一次性进场闸门（GridItem 复用不许重播）
  private entered: boolean = false;

  aboutToAppear(): void {
    // ★★★ 2026-10-14 奥森反馈「主界面滑动时下面的游戏总是闪现出来」⇒ 修：
    //   根因：GamesTab 传的是 `i < 8 ? i : 8` ⇒ 第 9 张之后【全是 index=8】
    //        ⇒ 这里 enterDelay(8) = 320ms 延迟 ⇒ 配合 Grid 的 cachedCount(6)
    //           一边滚一边新建卡片 ⇒ ★ 每张新卡都 opacity 0 起步、320ms 后才淡入 = "闪现"
    //   修法：index < 0 ⇒ 首屏之外（滚动中才创建）⇒ ★ 直接显示，不做入场动画
    // index < 0 ⇒ 首屏之外（滚动中才创建）⇒ ★ 什么都不做，保持 shown=true ⇒ 立刻可见
    // ★★★★ 2026-10-14 闪现【第 6 层 · 真凶】（奥森第四次反馈「好像还是闪现」）：
    //   根因：`aboutToAppear` 在【GridItem 被复用/回收】时【也会重跑】——
    //        老代码每次都执行 `this.shown = false`，再等 `enterDelay(index)`（最多 320ms）才亮
    //        ⇒ 滚动中卡片会【先消失一瞬间再出现】= ★ 他看到的"闪现"
    //   （前 5 层修的都是"单张卡片的静态属性"，没查到"生命周期会重跑"这一层）
    //   ⇒ 修法：一次性闸门 —— 每个组件实例【只允许播一次】进场动画，复用一律跳过
    if (this.entered) {
      return;
    }
    this.entered = true;
    if (this.index < 0) {
      return;
    }
    // 首屏卡片：先压成不可见，再按错峰延迟亮起（这才是真正的"错峰进场"）
    this.shown = false;
    setTimeout(() => {
      this.shown = true;
    }, enterDelay(this.index));
  }

    /** 游戏名：中文语言用中文名，其余一律用国际通用英文名 */
  /** 副标题：中文语言用中文，其余一律用英文 */
  private taglineText(): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    // ★ 2026-10-13 模拟器抓到：原来繁體直接返回 meta.tagline（简体）
    //   ⇒ 首页卡片在繁體下显示「宝石迷阵 / 交换消宝石」。displayTagline 内部对 zh-Hant 走 toTrad。
    return displayTagline(this.meta);
  }

  private gameTitle(): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    return displayName(this.meta);
  }

  /** 卡片底色（★ 先读 accentId 建立依赖，否则改主题色这张卡不重建） */
  private cardColor(): string {
    const observed: string = this.accentId;   // ← 依赖声明，别删
    return cardColorOf(this.meta);
  }

  /** 整句模板（读语言字段建立 ArkUI 依赖）—— 例：tn('{n} 天', '{n} d', 3) */
  private tn(zh: string, en: string, n: number, f1?: string, f2?: string, f5?: string): string {
    const observed: string = this.langCode;   // ← 依赖声明，别删
    return TN(zh, en, n, f1, f2, f5);   // ★ 复数透传（不传则退回旧行为）
  }

  /** 图标资源（354 款各有各的位图）；表里没有就返回 undefined，退回 emoji */
  private iconRes(): Resource | undefined {
    return iconOf(this.meta.id);
  }

build() {
    // ★ P1「图标挤到一起」的根因（2026-10-13）：
    //   改前图标是 **Text(emoji)**，大小/基线/行高全由**系统 emoji 字体**决定 ——
    //   macOS 与鸿蒙用的不是同一套字体（Apple Color Emoji / Noto Color Emoji），
    //   同一个码位在两端量出来的行盒不一样 ⇒ 图标会顶到 52vp 盒子的边缘、
    //   视觉上就"贴着标题"。现在换成**固定尺寸的位图**，盒子与图像都由我们定死。
    Stack({ alignContent: Alignment.BottomEnd }) {
    Row({ space: Space.sm }) {
      // ── 左：图标（固定 48vp；今日已玩时右上角一枚 ✓）──
      Stack({ alignContent: Alignment.TopEnd }) {
        if (this.iconRes() !== undefined) {
          Image(this.iconRes())
            .width(48).height(48)
            .objectFit(ImageFit.Contain)
            .draggable(false)
        } else {
          // 兜底：资源表里没有这一款（理论上不会发生）⇒ 仍然画 emoji，别开天窗
          Text(this.meta.icon).fontSize(FontSize.xl).width(48).height(48)
            .textAlign(TextAlign.Center)
        }
        if (this.playedToday) {
          Text('✓')
            .accessibilityLevel('no')
            .fontSize(FontSize.micro)
            .fontColor(Color.White)
            .backgroundColor(Palette.emerald)
            .borderRadius(Radius.full)
            .width(16).height(16)
            .textAlign(TextAlign.Center)
        }
      }
      .width(48).height(48)

      // ── 右：名称 + 副标题（与图标之间固定 Space.sm 间距，永不重叠）──
      Column({ space: Space.xs }) {
        Text(this.gameTitle())
          // ★ 2026-10-29（六设备·运动手表实测）：195vp 上标题被截成「宝...」
          //   ⇒ 极小屏（高 < 210vp）字号从 md 降到 sm、并允许两行，
          //     同时下面把 48vp 的图标藏起来，把宽度全让给标题。
          .fontSize(Bp.tinyWatch() ? FontSize.sm : FontSize.md)
          .maxLines(Bp.tinyWatch() ? 2 : 1)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          // ★★★ 2026-10-16 实拍德语大字模式：名字只剩 4 字（Beje… / Bre…）
          //   ⇒ 大字模式给【两行】，默认/简约仍一行
          .maxLines(this.uiMode === 'elder' ? 2 : 1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.taglineText())
          .fontSize(FontSize.xxs)
          // ★★★ 2026-10-14 奥森反馈「有些地方的文字显示明显不合适」（截图：2048 卡片副标题
          //   「合并数字，别把自己」被硬切）⇒ 根因：maxLines(1) 但【没设 textOverflow】
          //   ⇒ 超出部分直接【硬切】，连省略号都没有 ⇒ 看着像"文字坏了"。
          //   修法：① 自动缩小字号（minFontSize）⇒ 长副标题【尽量塞进一行】
          //        ② 真塞不下时用省略号（Ellipsis）⇒ 截断也体面 ✓
          .minFontSize(8)
          .maxFontSize(FontSize.xxs)
          // ★ 2026-10-19（对比度实测后改）：原来用 onColorSoft = 80% 白
          //   副标题在着色卡片上只有 2.51–3.16（最低的 lime 连 3.0 都不到）
          //   ⇒ 改纯白，3.09–4.10，+23%
          //   ⓘ 仍不到正文 4.5：那要把卡片从「实色底」改成「浅色底+深字」，属设计改动，留待真机看过
          .fontColor(Overlay.onColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          // ★ 真机实测（2026-10-13 模拟器 1320px）：长副标题（「一板一球，清空全场」）
          //   会换行，第二行贴到卡片右缘 ⇒ 给文字块留出右边距
          .padding({ right: Space.xs })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding(Space.md)
    .backgroundColor(this.cardColor())
    .borderRadius(Radius.lg)
    .shadow(Shadow.card)
    // ★ 动画 ①（2026-10-13）：与 GameHost 的整页容器配对做**跨页面**共享元素补间。
    //   ★ 用 `sharedTransition` 而不是 `geometryTransition`：
    //     d.ts（common.d.ts:20231）原文 —— "If the same id value is configured for a component
    //     on **the two pages**, this component is considered as a shared element of **the pages**"
    //     ⇒ 它**明确支持跨页面**；而 `geometryTransition` 的文档只讲"in and out components"（同页一对）。
    //   `Exchange` 是 d.ts 写的默认效果（位置/尺寸平滑交换），正合"卡片长大成整页"。
    .sharedTransition(this.sharedId, {
      // ★★★ 2026-10-14 奥森反馈「每个小游戏的开启动画非常诡异」⇒ 修：
      //   原来是 `Exchange`（位置/尺寸平滑交换）⇒ 卡片会长大成整页、内容被拉伸变形。
      //   但【目标组件是整页根容器】⇒ 整页内容都被从卡片尺寸"拽"到全屏
      //   ⇒ 文字横向拉扁、按钮压变形、emoji 缩放怪异；配上 Motion.slow 更明显。
      //   改为 `Static`：★ 元素只【平移】不改尺寸/外观 ⇒ 卡片滑到位即止，不再拉伸 ✓
      duration: Motion.base,
      // ⚠️ `curve` 的声明类型是 `Curve | string | ICurve`，但 ArkUI 的 DSL 属性**实际只吃 `Curve` 枚举**
      curve: Curve.Friction,
      type: SharedTransitionEffectType.Static
    })

      // ★ 连胜角标：叠在卡片右下角 —— 改前它占一行、把卡片撑高，
      //   同一行里"有连胜的卡"比"没连胜的卡"高出一截，网格参差不齐。
      //   叠上去之后卡片高度恒定，信息一点没少（奥森 2026-10-11 加的功能，不能丢）。
      if (this.streak > 0) {
        Row({ space: 3 }) {
          Text('🔥').fontSize(FontSize.micro)
            .accessibilityLevel('no')
          Text(this.tn('{n} 天', '{n} d', this.streak, '{n} день', '{n} дня', '{n} дней'))
            .fontSize(FontSize.micro).fontColor(Color.White).fontWeight(FontWeight.Bold)
        }
        .padding({ left: 7, right: 7, top: 2, bottom: 2 })
        .margin({ right: Space.xs, bottom: Space.xs })
        .backgroundColor(Overlay.chip)
        .borderRadius(Radius.full)
      }
    }
    .width('100%')
    // ★★★★ 2026-10-14 最终修（奥森给了决定性线索）：
    //   他说「成就页往下滑底下的成就就不会闪，是连贯出来的」
    //   ⇒ 对照发现：成就页的 GridItem **没有 .animation()**；游戏卡片有。
    //   ⇒ ★ 根因：`.animation()` 是【无条件绑定】的 —— 只要 GridItem 被新建/复用，
    //      ArkUI 就会对**前面整条链**做一次动画插值 ⇒ 卡片"动一下"= 闪。
    //      （与 shown 的值无关：前三次我改 index / cachedCount / shown 初值，都没碰到这条根因）
    //   ⇒ 修法：★ 去掉入场动画（opacity + translate），
    //      只保留【按下反馈】的 scale —— 与成就页保持一致 ⇒ 滚动时干净 ✓
    // ★★★★★ 2026-10-14 配合 GridItem 的 .height(232)：卡片【撑满】它
    //   ⇒ 每张卡等高 ⇒ 网格行位置可一次算出 ⇒ 滚动连贯（不再"跳着走"）
    .height('100%')
    .scale({ x: this.pressed ? Motion.pressScale : 1, y: this.pressed ? Motion.pressScale : 1 })
    // ★★★★★ 2026-10-14 闪现【第 8 层 · 真凶】（奥森「上面没收起来时也会闪现」「大哥我求你了」）：
    //   根因：`.animation()` 会把【前面整条链】都纳入动画 —— ★ 包括 `.backgroundColor(this.cardColor())`！
    //        而 GridItem 被【回收换成另一个游戏】时，cardColor() 从旧色【插值渐变】到新色
    //        ⇒ 中间那些"发白/淡色"的帧 = ★ 他看到的"整个方块闪"
    //        （连拍 16 帧实拍：左 7 帧实色、右 8 帧全发白 ⇒ 铁证）
    //   ⇒ 修法：删掉无条件 .animation()，改用 animateTo 只作用于【按下反馈】那一个状态
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        // ★ 按下反馈仍带动画，但【只动 pressed 这一个状态】⇒ 不会波及背景色
        animateTo({ duration: Motion.fast, curve: Motion.spring() }, () => {
          this.pressed = true;
        });
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        animateTo({ duration: Motion.fast, curve: Motion.spring() }, () => {
          this.pressed = false;
        });
      }
    })
    .onClick(() => {
      Haptics.tap();
      this.onOpen(this.meta.id);
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 250 })
        .onAction(() => {
          Haptics.press();
          this.onLongPress(this.meta.id);
        })
    )
    // ★★★ 2026-10-29（项目 F 阶段 2）：智慧屏焦点导航
    //   遥控器方向键在这里移动焦点，OK 键进游戏
    //   · Tv.on() 只在 Bp.isTv() 时为真 ⇒ 手机/平板/PC 上完全不起作用（零回归）
    //   · focusBox 用 4vp 粗框（3 米视距要看得见）
    .focusable(Tv.on())
    .focusBox(Tv.box())
    .onKeyEvent((e: KeyEvent) => {
      if (!Tv.on()) { return; }
      Tv.handleKey(e, () => { this.onOpen(this.meta.id); });
    })
  }
}

/** ───────────── 分类筛选条 ───────────── */
@Component
export struct CategoryBar {
  @StorageProp('lang') langCode: string = 'zh';
  /** ★ 2026-10-13（P5）：主题色观察源 —— 没它选中态不跟色 */
  @StorageProp('accent') accentId: string = Palette.primary;
  @Prop items: CatCount[] = [];
  @Prop selected: GameCategory = GameCategory.ALL;
  @Prop theme: Theme = Theme.light();
  onPick: (c: GameCategory) => void = () => {};

  /** 当前主题色（id 可能是 'system'，走 Accent 解析） */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  /**
   * 分类名（★ 2026-10-13 模拟器抓到：原来 zh-Hant 直接返回 `it.cat`（简体枚举值）
   * ⇒ 首页筛选条在繁體下显示「经典 45 / 逻辑 44」。改成走 L()：简体原文、繁体转换、其它语言英文）
   */
  private catLabel(c: GameCategory): string {
    const observed: string = this.langCode;
    return L(c, catLabelEn(c));
  }

  build() {
    Scroll() {
      Row({ space: Space.md }) {   // ★ 2026-10-13 奥森：「还是挤」⇒ 10vp → 16vp
        ForEach(this.items, (it: CatCount) => {
          // ★★★ 2026-10-16 实拍阿语抓到 BUG：it.count 是裸数字 ⇒
          //   阿拉伯语下分类胶囊显示【西文数字】，而同页计数行（走 Digits）是 ٠-٩ ⇒ 不一致
          //   ⇒ 修：套 Digits(..., this.langCode)（langCode 是 @StorageProp，换语言会重算）
          Text(this.catLabel(it.cat) + ' ' + Digits(String(it.count), this.langCode))
            .fontSize(FontSize.sm)
            .fontWeight(this.selected === it.cat ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selected === it.cat ? Color.White : this.theme.inkSoft)
            .padding({ left: Space.md, right: Space.md, top: Space.xs, bottom: Space.xs })
            // ★ 2026-10-13 奥森：「间隔宽度应该比较统一」
            //   原来宽度随内容走（「经典 46」比「逻辑 44」宽）⇒ 看着不齐
            .constraintSize({ minWidth: 112 })
            .textAlign(TextAlign.Center)
            // ★ P1 残留（2026-10-13 奥森指出「按键连在一起」）：
            //   原来未选中用 `surface`（= 白），而页面底也是白 ⇒ **边界看不见** ⇒ 看着像连成一片。
            //   改成 `surfaceAlt`（浅灰）⇒ 边界立起来。
            .backgroundColor(this.selected === it.cat ? this.accentColor() : this.theme.surfaceAlt)
            // ★ 再加一道 1px 描边：`surfaceAlt`(#FCFBF4) 和页面底太接近，
            //   光靠底色仍看不出边界 ⇒ 描边是让"每个键各是各的"最直接的手段
            .border({
              width: 1,
              color: this.selected === it.cat ? this.accentColor() : this.theme.line
            })
            .borderRadius(Radius.full)
            .animation({ duration: Motion.fast, curve: Motion.spring() })
            .onClick(() => {
              Haptics.tap();   // ★ 2026-10-19 按压反馈
              this.onPick(it.cat);
            })
        }, (it: CatCount) => it.cat)
      }
      .padding({ left: Space.lg, right: Space.lg })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
    // ★ 2026-10-13 奥森：「两个蓝色按钮连在一起，中间都没有白色间隔」
    //   根因：父 Column 没有 space，两个 chip 行上下紧贴 ⇒ 给分类条自己加上下边距
    .margin({ top: Space.lg, bottom: Space.xs })   // ★ 奥森要求「隔开一定距离」⇒ 10vp → 20vp
  }
}

