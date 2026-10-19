/**
 * 游戏宿主页 —— 顶栏 + 游戏区 + 结算弹窗
 *
 * ⚠️ 本文件的「导入区」与「分发链」由 tools/gen_dispatcher.py 自动生成，
 *    加游戏只需在 games/ 下新建文件（含 `gameId: 'xxx'`），然后跑：
 *        python3 tools/gen_dispatcher.py && bash build.sh
 *
 * 契约（GAME_BRIEF.md）：
 *   @Prop theme: Theme
 *   @Prop @Watch('onRestart') restartToken: number
 *   onFinish: (r: GameResult) => void
 */

import { router } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';
import { FontSize, Space, Radius, Palette, Motion, Theme, Shadow, Layout, Accent, Cell } from '../core/Design';
import { IconPress, RollingNumber } from '../core/MotionKit';
import { findGame, GameMeta, GameResult, difficultyFactor, displayTagline, displayName } from '../core/GameRegistry';
import { ProgressStore } from '../core/ProgressStore';
import { Haptics } from '../core/Haptics';
import { SparkBurst } from '../components/SparkBurst';
import { GameDiff } from '../core/GameDiff';
import { AppClock } from '../core/AppClock';
import { L, Digits } from '../core/I18n';
// ── 游戏实现（自动生成，勿手改）──
import { G2048 } from '../games/G2048';
import { GAbReversalOddball } from '../games/GAbReversalOddball';
import { GActionSequenceRecall } from '../games/GActionSequenceRecall';
import { GAffixFactory } from '../games/GAffixFactory';
import { GAkari } from '../games/GAkari';
import { GAlgebraicBalance } from '../games/GAlgebraicBalance';
import { GAlgebraicInequalitySolver } from '../games/GAlgebraicInequalitySolver';
import { GAlphabetSudoku } from '../games/GAlphabetSudoku';
import { GAnagramDefinition } from '../games/GAnagramDefinition';
import { GAngleFinder } from '../games/GAngleFinder';
import { GAreaPerimeterMatch } from '../games/GAreaPerimeterMatch';
import { GArithmeticChain } from '../games/GArithmeticChain';
import { GAssociativePairs } from '../games/GAssociativePairs';
import { GAttentionalBlink } from '../games/GAttentionalBlink';
import { GAttentionalBlinkProbe } from '../games/GAttentionalBlinkProbe';
import { GBalanceScale } from '../games/GBalanceScale';
import { GBaseConversionRun } from '../games/GBaseConversionRun';
import { GBaseShift } from '../games/GBaseShift';
import { GBejeweled } from '../games/GBejeweled';
import { GBinaryCode } from '../games/GBinaryCode';
import { GBinaryMatrixRank } from '../games/GBinaryMatrixRank';
import { GBinaryMatrixRankAll } from '../games/GBinaryMatrixRankAll';
import { GBinaryPuzzle } from '../games/GBinaryPuzzle';
import { GBinaryScaleBalance } from '../games/GBinaryScaleBalance';
import { GBinomialMatch } from '../games/GBinomialMatch';
import { GBlinkDetector } from '../games/GBlinkDetector';
import { GBlockCount3d } from '../games/GBlockCount3d';
import { GBlockEscape } from '../games/GBlockEscape';
import { GBlockStackingPhysics } from '../games/GBlockStackingPhysics';
import { GBoxCompletion } from '../games/GBoxCompletion';
import { GBreakout } from '../games/GBreakout';
import { GBridges } from '../games/GBridges';
import { GBridgesAll } from '../games/GBridgesAll';
import { GBubbleShooter } from '../games/GBubbleShooter';
import { GCalculationSprint } from '../games/GCalculationSprint';
import { GCardCountingMemory } from '../games/GCardCountingMemory';
import { GCategoryFluency } from '../games/GCategoryFluency';
import { GChainReaction } from '../games/GChainReaction';
import { GChalkAndTalk } from '../games/GChalkAndTalk';
import { GChangeBlindness } from '../games/GChangeBlindness';
import { GCheckers } from '../games/GCheckers';
import { GChimpTest } from '../games/GChimpTest';
import { GChoiceReactionTime } from '../games/GChoiceReactionTime';
import { GCircuitConnect } from '../games/GCircuitConnect';
import { GClassicMaze } from '../games/GClassicMaze';
import { GCognateCatch } from '../games/GCognateCatch';
import { GCollatz } from '../games/GCollatz';
import { GColorFlood } from '../games/GColorFlood';
import { GColorMatch } from '../games/GColorMatch';
import { GColorMazeNav } from '../games/GColorMazeNav';
import { GColorWordMatchUp } from '../games/GColorWordMatchUp';
import { GCommonDenominator } from '../games/GCommonDenominator';
import { GCompassMaze } from '../games/GCompassMaze';
import { GComplexFoldingNets } from '../games/GComplexFoldingNets';
import { GCompoundConnect } from '../games/GCompoundConnect';
import { GConjunctionSearch } from '../games/GConjunctionSearch';
import { GConnectFour } from '../games/GConnectFour';
import { GConsonantReconstruct } from '../games/GConsonantReconstruct';
import { GContextClues } from '../games/GContextClues';
import { GContinuousPairedAssociate } from '../games/GContinuousPairedAssociate';
import { GContinuousRecognition } from '../games/GContinuousRecognition';
import { GConundrumAnagram } from '../games/GConundrumAnagram';
import { GCorsiBackwardSpan } from '../games/GCorsiBackwardSpan';
import { GCorsiBlocks } from '../games/GCorsiBlocks';
import { GCountdownMath } from '../games/GCountdownMath';
import { GCountingSheep } from '../games/GCountingSheep';
import { GCountingSpan } from '../games/GCountingSpan';
import { GCrossSectionSlice } from '../games/GCrossSectionSlice';
import { GCrossword } from '../games/GCrossword';
import { GCrown } from '../games/GCrown';
import { GCryptoArithmetic } from '../games/GCryptoArithmetic';
import { GCryptogram } from '../games/GCryptogram';
import { GCryptogramAll } from '../games/GCryptogramAll';
import { GCubeNetFold } from '../games/GCubeNetFold';
import { GD2Attention } from '../games/GD2Attention';
import { GDefinitionDash } from '../games/GDefinitionDash';
import { GDelayedMatchSample } from '../games/GDelayedMatchSample';
import { GDigitSpanReverse } from '../games/GDigitSpanReverse';
import { GDigitSwapEq } from '../games/GDigitSwapEq';
import { GDirectionsRecall } from '../games/GDirectionsRecall';
import { GDistractorMatrix } from '../games/GDistractorMatrix';
import { GDividedAttention } from '../games/GDividedAttention';
import { GDivisibilityDash } from '../games/GDivisibilityDash';
import { GDnms } from '../games/GDnms';
import { GDominosa } from '../games/GDominosa';
import { GDoodleJump } from '../games/GDoodleJump';
import { GDoubleNBack } from '../games/GDoubleNBack';
import { GDoubleTrouble } from '../games/GDoubleTrouble';
import { GDualCoding } from '../games/GDualCoding';
import { GDualMirror } from '../games/GDualMirror';
import { GDualTaskMemory } from '../games/GDualTaskMemory';
import { GDynamicSalience } from '../games/GDynamicSalience';
import { GEinsteinRiddle } from '../games/GEinsteinRiddle';
import { GEtymologyOrigin } from '../games/GEtymologyOrigin';
import { GEtymonOddball } from '../games/GEtymonOddball';
import { GEventTimelineMemory } from '../games/GEventTimelineMemory';
import { GExponentTower } from '../games/GExponentTower';
import { GFaceNameAssociation } from '../games/GFaceNameAssociation';
import { GFaceTraitAssociation } from '../games/GFaceTraitAssociation';
import { GFactBinder } from '../games/GFactBinder';
import { GFactorFinder } from '../games/GFactorFinder';
import { GFeatureMatrixRecall } from '../games/GFeatureMatrixRecall';
import { GFeatureMatrixRecallAll } from '../games/GFeatureMatrixRecallAll';
import { GFibonacciMerge } from '../games/GFibonacciMerge';
import { GFillomino } from '../games/GFillomino';
import { GFindWord } from '../games/GFindWord';
import { GFlankerTest } from '../games/GFlankerTest';
import { GFlappy } from '../games/GFlappy';
import { GFocusTunnel } from '../games/GFocusTunnel';
import { GFractionMatch } from '../games/GFractionMatch';
import { GFractionMatcher } from '../games/GFractionMatcher';
import { GFractionalPizza } from '../games/GFractionalPizza';
import { GFreecell } from '../games/GFreecell';
import { GFrequencyTap } from '../games/GFrequencyTap';
import { GFutoshiki } from '../games/GFutoshiki';
import { GGame24 } from '../games/GGame24';
import { GGearRotation } from '../games/GGearRotation';
import { GGearTrainDirection } from '../games/GGearTrainDirection';
import { GGeometricVision } from '../games/GGeometricVision';
import { GGhostTap } from '../games/GGhostTap';
import { GGo9 } from '../games/GGo9';
import { GGoNoGo } from '../games/GGoNoGo';
import { GGokigenNaname } from '../games/GGokigenNaname';
import { GGomoku } from '../games/GGomoku';
import { GGrammarPolice } from '../games/GGrammarPolice';
import { GGrammarSort } from '../games/GGrammarSort';
import { GGraphCoordinatePlot } from '../games/GGraphCoordinatePlot';
import { GGravitySort } from '../games/GGravitySort';
import { GGridDisplacement } from '../games/GGridDisplacement';
import { GGroceryList } from '../games/GGroceryList';
import { GHanoi } from '../games/GHanoi';
import { GHeyawake } from '../games/GHeyawake';
import { GHitori } from '../games/GHitori';
import { GHitoriAll } from '../games/GHitoriAll';
import { GHomophoneHunt } from '../games/GHomophoneHunt';
import { GHueSort } from '../games/GHueSort';
import { GInequalityBalanceOps } from '../games/GInequalityBalanceOps';
import { GInequalityDash } from '../games/GInequalityDash';
import { GInterlockPuzzle } from '../games/GInterlockPuzzle';
import { GKakurasuSums } from '../games/GKakurasuSums';
import { GKakuro } from '../games/GKakuro';
import { GKakuroMini } from '../games/GKakuroMini';
import { GKenken } from '../games/GKenken';
import { GKlotski } from '../games/GKlotski';
import { GKurodoko } from '../games/GKurodoko';
import { GLaserLink } from '../games/GLaserLink';
import { GLaserReflect } from '../games/GLaserReflect';
import { GLetterBridge } from '../games/GLetterBridge';
import { GLetterCancellation } from '../games/GLetterCancellation';
import { GLetterFrequencyScan } from '../games/GLetterFrequencyScan';
import { GLetterGridSwapper } from '../games/GLetterGridSwapper';
import { GLifeGame } from '../games/GLifeGame';
import { GLighthouses } from '../games/GLighthouses';
import { GLightsOut } from '../games/GLightsOut';
import { GLockPattern } from '../games/GLockPattern';
import { GLogicalSyllogisms } from '../games/GLogicalSyllogisms';
import { GMagicSquares } from '../games/GMagicSquares';
import { GMagnets } from '../games/GMagnets';
import { GMahjongSolitaire } from '../games/GMahjongSolitaire';
import { GMancala } from '../games/GMancala';
import { GMandalaRecall } from '../games/GMandalaRecall';
import { GMandelbrot } from '../games/GMandelbrot';
import { GMastermind } from '../games/GMastermind';
import { GMasyu } from '../games/GMasyu';
import { GMatch3 } from '../games/GMatch3';
import { GMathGuess } from '../games/GMathGuess';
import { GMathMaze } from '../games/GMathMaze';
import { GMathPath } from '../games/GMathPath';
import { GMatrixMultiplier } from '../games/GMatrixMultiplier';
import { GMatrixMultiplierMatch } from '../games/GMatrixMultiplierMatch';
import { GMatrixReasoning } from '../games/GMatrixReasoning';
import { GMazeNav3d } from '../games/GMazeNav3d';
import { GMemory } from '../games/GMemory';
import { GMemoryMatrix } from '../games/GMemoryMatrix';
import { GMemoryPalace } from '../games/GMemoryPalace';
import { GMentalAbacus } from '../games/GMentalAbacus';
import { GMentalCalendar } from '../games/GMentalCalendar';
import { GMentalMapping } from '../games/GMentalMapping';
import { GMentalRotation } from '../games/GMentalRotation';
import { GMinesweeper } from '../games/GMinesweeper';
import { GMirrorImage } from '../games/GMirrorImage';
import { GMirrorMaze } from '../games/GMirrorMaze';
import { GMirrorTracing } from '../games/GMirrorTracing';
import { GMissingOperator } from '../games/GMissingOperator';
import { GMissingVowels } from '../games/GMissingVowels';
import { GModularClockArithmetic } from '../games/GModularClockArithmetic';
import { GModuloClock } from '../games/GModuloClock';
import { GModuloPath } from '../games/GModuloPath';
import { GMultiTrackCounter } from '../games/GMultiTrackCounter';
import { GMultipleObjectTracking } from '../games/GMultipleObjectTracking';
import { GNBack } from '../games/GNBack';
import { GNarrativeRecall } from '../games/GNarrativeRecall';
import { GNavonHierarchical } from '../games/GNavonHierarchical';
import { GNegativeSpaceDetection } from '../games/GNegativeSpaceDetection';
import { GNim } from '../games/GNim';
import { GNonogram } from '../games/GNonogram';
import { GNoriNori } from '../games/GNoriNori';
import { GNumberBonds } from '../games/GNumberBonds';
import { GNumberBondsAll } from '../games/GNumberBondsAll';
import { GNumericalEstimation } from '../games/GNumericalEstimation';
import { GNurikabe } from '../games/GNurikabe';
import { GObjectDisplacement } from '../games/GObjectDisplacement';
import { GObjectShuffle } from '../games/GObjectShuffle';
import { GOddEvenFlash } from '../games/GOddEvenFlash';
import { GOddOneOut } from '../games/GOddOneOut';
import { GOddRotation } from '../games/GOddRotation';
import { GOneLetterShift } from '../games/GOneLetterShift';
import { GOperationSpan } from '../games/GOperationSpan';
import { GOrbitTap } from '../games/GOrbitTap';
import { GOxymoronHunt } from '../games/GOxymoronHunt';
import { GPalindromeBuilder } from '../games/GPalindromeBuilder';
import { GPangramSprint } from '../games/GPangramSprint';
import { GPaperFolding } from '../games/GPaperFolding';
import { GPathFinder } from '../games/GPathFinder';
import { GPathIntersect } from '../games/GPathIntersect';
import { GPathRecall } from '../games/GPathRecall';
import { GPatternSequenceDraw } from '../games/GPatternSequenceDraw';
import { GPegSolitaire } from '../games/GPegSolitaire';
import { GPercentagePeak } from '../games/GPercentagePeak';
import { GPercentageShopping } from '../games/GPercentageShopping';
import { GPeripheralFocus } from '../games/GPeripheralFocus';
import { GPerspectiveShiftView } from '../games/GPerspectiveShiftView';
import { GPerspectiveTaking } from '../games/GPerspectiveTaking';
import { GPhoneticGuess } from '../games/GPhoneticGuess';
import { GPipes } from '../games/GPipes';
import { GPixelMimic } from '../games/GPixelMimic';
import { GPolyominoTiling } from '../games/GPolyominoTiling';
import { GPong } from '../games/GPong';
import { GPortmanteauSplit } from '../games/GPortmanteauSplit';
import { GPosnerSpatialCueing } from '../games/GPosnerSpatialCueing';
import { GPrimeFactorTrees } from '../games/GPrimeFactorTrees';
import { GPrimeGapHunt } from '../games/GPrimeGapHunt';
import { GPrimeHunter } from '../games/GPrimeHunter';
import { GProbeDigitSpan } from '../games/GProbeDigitSpan';
import { GPythagoreanTripleBuilder } from '../games/GPythagoreanTripleBuilder';
import { GQuickMath } from '../games/GQuickMath';
import { GRadicalRoots } from '../games/GRadicalRoots';
import { GReadingSpan } from '../games/GReadingSpan';
import { GReflexTap } from '../games/GReflexTap';
import { GRelationalMemory } from '../games/GRelationalMemory';
import { GReverseStroop } from '../games/GReverseStroop';
import { GReversi } from '../games/GReversi';
import { GRhymeMaster } from '../games/GRhymeMaster';
import { GRhythmMaster } from '../games/GRhythmMaster';
import { GRomanArithmetic } from '../games/GRomanArithmetic';
import { GRoomInspector } from '../games/GRoomInspector';
import { GRotatingMaze } from '../games/GRotatingMaze';
import { GRuleSwitcher } from '../games/GRuleSwitcher';
import { GRunningMemorySpan } from '../games/GRunningMemorySpan';
import { GSchulte } from '../games/GSchulte';
import { GSdmt } from '../games/GSdmt';
import { GSemanticAssociation } from '../games/GSemanticAssociation';
import { GSemanticDistance } from '../games/GSemanticDistance';
import { GSemanticLink } from '../games/GSemanticLink';
import { GSentenceUnscramble } from '../games/GSentenceUnscramble';
import { GSequenceSleuth } from '../games/GSequenceSleuth';
import { GSequenceStack } from '../games/GSequenceStack';
import { GSetTheoryVenn } from '../games/GSetTheoryVenn';
import { GShadowPivot } from '../games/GShadowPivot';
import { GShapeShifter } from '../games/GShapeShifter';
import { GShellGame } from '../games/GShellGame';
import { GShikaku } from '../games/GShikaku';
import { GSieveVisualizer } from '../games/GSieveVisualizer';
import { GSilentLetterSearch } from '../games/GSilentLetterSearch';
import { GSilhouetteMatch } from '../games/GSilhouetteMatch';
import { GSilhouetteMatchOrtho } from '../games/GSilhouetteMatchOrtho';
import { GSimonCommand } from '../games/GSimonCommand';
import { GSimonSays } from '../games/GSimonSays';
import { GSimonSequence } from '../games/GSimonSequence';
import { GSkyscrapers } from '../games/GSkyscrapers';
import { GSlide15 } from '../games/GSlide15';
import { GSlidePuzzle } from '../games/GSlidePuzzle';
import { GSlitherlink } from '../games/GSlitherlink';
import { GSnake } from '../games/GSnake';
import { GSnake3D } from '../games/GSnake3D';
import { GSokoban } from '../games/GSokoban';
import { GSolitaire } from '../games/GSolitaire';
import { GSopt } from '../games/GSopt';
import { GSortingVisualizer } from '../games/GSortingVisualizer';
import { GSourceMonitoring } from '../games/GSourceMonitoring';
import { GSpatialCabinetMemory } from '../games/GSpatialCabinetMemory';
import { GSpatialConflict } from '../games/GSpatialConflict';
import { GSpellingSprint } from '../games/GSpellingSprint';
import { GSpiderSolitaire } from '../games/GSpiderSolitaire';
import { GSpoonerismSolver } from '../games/GSpoonerismSolver';
import { GSpotlightTrack } from '../games/GSpotlightTrack';
import { GStaircaseMemory } from '../games/GStaircaseMemory';
import { GSternbergTask } from '../games/GSternbergTask';
import { GStopSignal } from '../games/GStopSignal';
import { GStoryBuilder } from '../games/GStoryBuilder';
import { GStroopNumberSize } from '../games/GStroopNumberSize';
import { GStroopTest } from '../games/GStroopTest';
import { GSubitizingRush } from '../games/GSubitizingRush';
import { GSudoku } from '../games/GSudoku';
import { GSudokuHex } from '../games/GSudokuHex';
import { GSumPyramid } from '../games/GSumPyramid';
import { GSumSnake } from '../games/GSumSnake';
import { GSwitchTask } from '../games/GSwitchTask';
import { GSyllableStack } from '../games/GSyllableStack';
import { GSymbolDigitAssoc } from '../games/GSymbolDigitAssoc';
import { GSymbolLogic } from '../games/GSymbolLogic';
import { GSymbolicFlanker } from '../games/GSymbolicFlanker';
import { GSymmetry } from '../games/GSymmetry';
import { GSymmetrySpan } from '../games/GSymmetrySpan';
import { GTangleFix } from '../games/GTangleFix';
import { GTangram } from '../games/GTangram';
import { GTapa } from '../games/GTapa';
import { GTarget10 } from '../games/GTarget10';
import { GTargetNumber } from '../games/GTargetNumber';
import { GTaskSwitching } from '../games/GTaskSwitching';
import { GTemporalOrder } from '../games/GTemporalOrder';
import { GTemporalOrderJudgment } from '../games/GTemporalOrderJudgment';
import { GTennerGrid } from '../games/GTennerGrid';
import { GTentsAndTrees } from '../games/GTentsAndTrees';
import { GTetris } from '../games/GTetris';
import { GTicTacToe } from '../games/GTicTacToe';
import { GTopology } from '../games/GTopology';
import { GTowerOfHanoi } from '../games/GTowerOfHanoi';
import { GTowerOfLondon } from '../games/GTowerOfLondon';
import { GTracePath } from '../games/GTracePath';
import { GTrailMaking } from '../games/GTrailMaking';
import { GTripleSequence } from '../games/GTripleSequence';
import { GTripletsLogic } from '../games/GTripletsLogic';
import { GTypingSpeed } from '../games/GTypingSpeed';
import { GTypoglycemiaDecoder } from '../games/GTypoglycemiaDecoder';
import { GUnitConverterPro } from '../games/GUnitConverterPro';
import { GVectorDotProduct } from '../games/GVectorDotProduct';
import { GVectorGridAlignment } from '../games/GVectorGridAlignment';
import { GVektorVector } from '../games/GVektorVector';
import { GVennNumbers } from '../games/GVennNumbers';
import { GVerbalAnalogies } from '../games/GVerbalAnalogies';
import { GVigilanceTask } from '../games/GVigilanceTask';
import { GVisualCrowdingAcuity } from '../games/GVisualCrowdingAcuity';
import { GVisualSearch } from '../games/GVisualSearch';
import { GVisualSearchAll } from '../games/GVisualSearchAll';
import { GVisualSearchConjunction } from '../games/GVisualSearchConjunction';
import { GVisualStatisticalLearning } from '../games/GVisualStatisticalLearning';
import { GVocabularyBuilder } from '../games/GVocabularyBuilder';
import { GVowelReconstruct } from '../games/GVowelReconstruct';
import { GWaterSort } from '../games/GWaterSort';
import { GWireframe3dRotation } from '../games/GWireframe3dRotation';
import { GWisconsinCardSorting } from '../games/GWisconsinCardSorting';
import { GWordAssociationRecall } from '../games/GWordAssociationRecall';
import { GWordGridConnection } from '../games/GWordGridConnection';
import { GWordLadder } from '../games/GWordLadder';
import { GWordLadderStep } from '../games/GWordLadderStep';
import { GWordMastermind } from '../games/GWordMastermind';
import { GWordPairAssociateMemory } from '../games/GWordPairAssociateMemory';
import { GWordScramble } from '../games/GWordScramble';
import { GWordSearch } from '../games/GWordSearch';
import { GWordSnakeTrail } from '../games/GWordSnakeTrail';
import { GWordSurge } from '../games/GWordSurge';
import { GWordWheel } from '../games/GWordWheel';
import { GWordle } from '../games/GWordle';
import { GYajilin } from '../games/GYajilin';

@Entry
@Component
struct GameHost {

  /** 难度标签（读 diffTick 建立 ArkUI 依赖） */
  private diffLabel(): string {
    const tick: number = this.diffTick;
    const d: number = ProgressStore.diffOf(this.gameId);
    // ★★★ 2026-10-16 实拍日语发现：原来非中文一律用【英文】难度名 ⇒ 日语玩家看到 "Normal"
    //   ⇒ 改走 this.t(cn, en)：EXTRA 里有 12 语言的难度名（简单/普通/困难）
    const cn: string = ProgressStore.DIFF_NAME[d][0];
    const en: string = ProgressStore.DIFF_NAME[d][1];
    return this.t(cn, en);
  }

  /** 难度对应的颜色：简单绿 / 普通蓝 / 困难橙 */
  private diffColor(): string {
    const d: number = ProgressStore.diffOf(this.gameId);
    if (d === 0) {
      return Palette.emerald;
    }
    if (d === 2) {
      return Palette.orange;
    }
    return this.accentColor();
  }

  /** 取当前语言的文案（必须读 langCode 建立 ArkUI 依赖，否则不重渲染） */
  private t(zh: string, en: string): string {
    const observed: string = this.langCode;
    // ★ 2026-10-13（P4）：这里原来是中英二元式 `observed === 'en' ? en : zh` ——
    //   日/韩/西/法/德/葡/俄/意/阿 十种语言全退中文，繁体也被吞。必须走 L()（12 语言 + 简繁转换）。
    return L(zh, en);
  }
  @StorageProp('lang') langCode: string = 'zh';
  /** ★ 2026-10-13（P5）：主题色观察源 —— 设置页改色，本页立刻跟 */
  @StorageProp('accent') accentId: string = Palette.primary;
  /** 当前主题色（id 可能是 'system'，一律走 Accent 解析） */
  private accentColor(): string {
    const observed: string = this.accentId;
    return Accent.color(this.accentId);
  }

  @State meta: GameMeta | undefined = undefined;
  /** ★ 动画 ① 共享元素转场 id（与首页那张卡同名；空串 = 不参与） */
  @State private sharedId: string = '';
  @State gameId: string = '';
  @State nonce: number = 0;
  // ★ 难度标签必须读一个 @State —— 只调 ProgressStore.diffOf() 的话
  //   ArkUI 看不到依赖，切了难度标签不会重渲染（同一个坑踩了四次）
  @State diffTick: number = 0;
  @State dark: boolean = false;
  @State showResult: boolean = false;
  @State lastGain: number = 0;
  /** ★ 本局新解锁的成就（结算面板要展示并庆祝） */
  @State newAch: string[] = [];
  /** ★ 滚动计数用（0 → 最终值）：直接内联 Text 读它，才能逐帧刷新 */
  @State gainShown: number = 0;
  @State scoreShown: number = 0;
  /** 数字滚动器（原来是 countTimer 手写的那套，2026-10-13 提取成公共件） */
  private roll: RollingNumber = new RollingNumber();
  @State lastScore: number = 0;
  @State lastMs: number = 0;
  @State lastSolved: boolean = false;
  @State fav: boolean = false;
  @State pop: boolean = false;
  // ★★★「动画拉满」第 2 层：胜利粒子进度（0→1 由 animateTo 推）
  @State burstP: number = 0;
  /** ★ 2026-10-13「动画拉满」item ④：顶栏图标按下弹一下 */
  @State private backPressed: boolean = false;
  @State levelUpTo: number = 0;

  aboutToAppear(): void {
    const p: Record<string, Object> = router.getParams() as Record<string, Object>;
    if (p && p.id !== undefined) {
      this.gameId = p.id as string;
    }
    // ★ 动画 ①：从首页带过来的共享元素 id（空串 = 不做共享转场）
    if (p && p.sharedId !== undefined) {
      this.sharedId = p.sharedId as string;
    }
    // ★★★ 2026-10-14 奥森反馈「退出动画还是很诡异」⇒ 根因修：
    //   首页的 flyingId 在 400ms 后清了，但 GameHost 的 sharedId 【一直挂着从不清】
    //   ⇒ 退出时游戏页根容器**还带着 sharedTransition('card-xxx')**，而对面【已无伙伴】
    //   ⇒ 无伙伴的共享元素 = 未定义行为 ⇒ 退出动画诡异 ✗
    //   修法：与首页同步 —— 进入动画走完（Motion.base 260ms + 余量）就清空 sharedId
    //        ⇒ 退出时两端都没有共享元素 ⇒ 只剩干净的 PageTransitionExit ✓
    setTimeout(() => {
      this.sharedId = '';
    }, 420);
    // ★ 必须在 this.gameId 赋值**之后**登记 —— 写在前面时它还是空串（真踩过）
    GameDiff.enter(this.gameId);
    this.meta = findGame(this.gameId);
    this.fav = ProgressStore.isFavorite(this.gameId);
    // 游戏时屏幕常亮（对标项目的 wakelock 体验）
    try {
      window.getLastWindow(getContext(this)).then((w: window.Window) => {
        w.setWindowKeepScreenOn(true);
      });
    } catch (e) {
      // 拿不到窗口就算了，不影响游戏
    }
  }

  aboutToDisappear(): void {
    // ★ 先把数字滚动的计时器停掉 —— 否则退出游戏页后它还在推帧改 @State
    //   （本项目纪律：别在后台每帧 setState）
    this.roll.stop();
    try {
      window.getLastWindow(getContext(this)).then((w: window.Window) => {
        w.setWindowKeepScreenOn(false);
      });
    } catch (e) {
    }
  }

  // ★★★ 2026-10-17 13:3x 真 BUG 修复（第七轮实测抓到的）：
  //   玩「不等式冲刺」剩 56s → 按 HOME 切后台 30 秒 → 回来只剩 17s
  //   根因：25 个倒计时游戏的 setInterval 每秒无条件减 1，没人管前台/后台
  //   修法：本页 onPageHide 时把 AppClock 置为暂停；onPageShow 时恢复
  //        ⇒ 各倒计时游戏在 tick 里问 AppClock.isPaused()，暂停期跳过
  onPageShow(): void {
    AppClock.show();
  }

  onPageHide(): void {
    AppClock.hide();
  }

  private theme(): Theme {
    return this.dark ? Theme.dark() : Theme.light();
  }

  /** 所有游戏结算都走这里 */
  /**
   * ★ 手感：数字**滚动计数**（0 → target，约 610ms）
   *
   * 为什么用 setInterval 而不是 animateTo：
   *   `animateTo` 只能插值**属性**，插不了"显示用的数字" ⇒ 只能自己逐帧推。
   *   缓动取 easeOutCubic（先快后慢）—— 比线性更有"冲上去再稳住"的手感。
   * ⚠️ 重开一局要先清掉上一个计时器，否则数字会抖（已用 countTimer 兜住）
   */
  /**
   * ★ 2026-10-13「动画拉满」item ④：改为**复用公共件** `RollingNumber`（`core/MotionKit.ets`）
   *
   * 为什么搬走：统计页也要"数字滚上去"，两处各写一份必然漂移
   * （这份的缓动/帧数就是我从这里提取出去的原文）。
   * 行为完全不变：18 帧 × 34ms ≈ 610ms、easeOutCubic、收尾写准确值。
   */
  private countUp(target: number, apply: (v: number) => void): void {
    this.roll.to(target, apply);
  }

  private handleFinish(r: GameResult): void {
    const m: GameMeta | undefined = this.meta;
    const baseXp: number = m ? m.baseXp : 10;
    const factor: number = m ? difficultyFactor(m.difficulty) : 1;
    const gain: number = ProgressStore.finishGame(r.gameId, r.solved, baseXp, factor * ProgressStore.DIFF_XP[ProgressStore.diffOf(r.gameId)], r.score, r.durationMs);
    this.lastGain = gain;
    this.lastScore = r.score;
    this.lastMs = r.durationMs;
    this.lastSolved = r.solved;
    this.levelUpTo = AppStorage.get<number>('levelUpTo') ?? 0;
    this.pop = false;
    // ★ 手感（2026-10-12 手感专项）：**结束的瞬间必须有触感**，而且成功/失败要能分辨
    //   · 通关 + 升级  ⇒ celebrate()  三连轻震（大时刻）
    //   · 通关         ⇒ success()    一记略重的
    //   · 没通关       ⇒ fail()       两下短震（和 success 明显不同）
    // ★ 手感：得分与经验**滚上去**（0 → 最终值，约 700ms）
    this.countUp(r.score, (v2: number) => { this.scoreShown = v2; });
    // ★★★ 2026-10-19 真机抓到：结算弹窗显示的是 scoreShown（滚动动画中间值）
    //   实测：游戏内得分 1050，结算里却是 442 —— 动画被打断就停在半路
    //   ⇒ 动画走完（18×34≈612ms）后强制对齐真值，保证显示永远等于 lastScore
    setTimeout(() => { this.scoreShown = r.score; }, 760);
    setTimeout(() => {
      this.countUp(gain, (v2: number) => { this.gainShown = v2; });
    }, 140);
    // ★ 手感：解锁成就 = 大时刻 ⇒ 三连庆祝（优先于普通通关）
    this.newAch = ProgressStore.lastNewAch;
    if (r.solved) {
      if (this.levelUpTo > 0 || this.newAch.length > 0) {
        Haptics.celebrate();
      } else {
        Haptics.success();
      }
    } else {
      Haptics.fail();
    }
    animateTo({ duration: Motion.sheet, curve: Motion.spring() }, () => {
      this.showResult = true;
    });
    // ★★★「动画拉满」胜利粒子：只在通关时放，和 pop（300ms）同一拍起飞
    //   失败不放 —— 失败的情绪应该是"沉"，不是"散"
    if (r.solved) {
      this.burstP = 0;
      setTimeout(() => {
        // ★★★ 2026-10-19 真机验证后改：原来用 animateTo 改 @State 再传 @Prop，
        //   Canvas 的 @Watch 拿不到中间值 ⇒ 粒子一次都没画出来（8 秒动画也看不到）
        //   ⇒ 改用手动逐帧推进（与 MotionKit.RollingNumber 同一套做法）
        this.burstP = 0;
        let bi: number = 0;
        const bTimer: number = setInterval(() => {
          bi = bi + 1;
          this.burstP = Math.min(1, bi / 30);
          if (bi >= 30) { clearInterval(bTimer); }
        }, 33);
      }, Motion.base + 40);
    }
    // ★★★ 2026-10-14 奥森反馈「每个小游戏的开启动画非常诡异」⇒ 第二个根因修：
    //   原来是 60ms 就置 pop=true ⇒ 而共享元素转场是 Motion.base(260ms)
    //   ⇒ 【两套动画重叠 200ms】：页面还在平移/缩放时，各元素已经在淡入上浮
    //   ⇒ 视觉上就是"诡异"（两种运动叠加，谁也不清楚）
    //   改为等转场【完全结束】再起错峰进场 ⇒ 先"落位"，再"亮起来" ✓
    setTimeout(() => {
      this.pop = true;
    }, Motion.base + 40);   // 260 + 40 = 300ms
  }

/** 未实现的游戏：给个友好的占位，而不是白屏 */
@Builder
    placeholder() {
    Column({ space: Space.md }) {
      Text(this.meta ? this.meta.icon : '🎮').fontSize(56)
      Text(this.t('这一款还在路上', 'This one is still on the way')).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Text(this.meta ? displayName(this.meta) : '')   // ★ 繁體/其它语言都要走 displayName（2026-10-13 模拟器抓到）
        .fontSize(FontSize.sm).fontColor(this.theme().inkSoft)
      Text(this.t('玩法：', 'How to play: ') + (this.meta ? displayTagline(this.meta) : ''))
        .fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
        .textAlign(TextAlign.Center)
      Text(this.t('换一款玩玩？', 'Try another?')).fontSize(FontSize.xs).fontColor(this.theme().inkFaint)
        .margin({ top: Space.lg })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(Space.xxl)
}

  /**
   * ★ 页面转场（2026-10-13「动画拉满」专项 item ②）
   *
   * 进游戏（`router.pushUrl('pages/GameHost')`，type = Push）：
   *   **从下方轻微上浮 + 淡入** —— 做出"卡片长成了这一页"的方向感
   *   （真正点对点的共享元素转场要 `geometryTransition`，那是 item ①，风险高，这一步先打底）。
   * 返回（type = Pop）：**反向**（往下退 + 淡出），和来路对称。
   *
   * ⚠️ 用 `PageTransitionEnter/Exit` 而**不是** `TransitionEffect`：
   *   后者是组件级转场，挂页面根节点不响应路由事件（`page_transition.d.ts`）。
   * ⚠️ 位移量只给 18vp：357 款游戏页首帧本来就有布局压力，位移一大就看出掉帧。
   */
  pageTransition() {
    PageTransitionEnter({ type: RouteType.Push, duration: Motion.base })
      .translate({ y: 18 })
      .opacity(0)
    // ★ 2026-10-13：退出时长由 Motion.fast(180ms) 改成 Motion.base(260ms)
    //   原因（奥森：「退出回主界面的切换动画十分诡异」）：
    //     进入 260ms、退出只有 180ms ⇒ 一来一回【不对称】⇒ 看着"闪一下"
    //   ⇒ 与进入对称，观感才顺
    PageTransitionExit({ type: RouteType.Pop, duration: Motion.base })
      .translate({ y: 18 })
      .opacity(0)
  }

  /**
   * 结算弹窗里 🎉 的纵向位置（百分比字符串）
   *
   * 为什么需要它：弹窗高度会随界面模式变（padding、行高、按钮高度都跟着 Cell.k 缩放），
   *   而 🎉 的字号是写死的 44 ⇒ 弹窗越高，🎉 在屏幕上就越靠上。
   *   粒子如果固定锚在 72%，elder 模式下会比 emoji 低 11%（约 88vp），看起来像从空气里炸出来。
   *
   * 实测换算（屏高 800vp）：
   *   normal(Cell.k=1)     弹窗 297vp ⇒ 🎉 在 70.1%
   *   elder (Cell.k=1.33)  弹窗 384vp ⇒ 🎉 在 60.8%
   *   simple(Cell.k=0.9)   弹窗 更矮   ⇒ 🎉 在 ≈72.7%
   * ⇒ 用 70 - (k-1)*27 拟合，三点误差都 < 1%
   */
  private burstY(): string {
    const k: number = Cell.k;
    const y: number = 70 - (k - 1) * 27;
    return y.toFixed(1) + '%';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // ── 顶栏 ──
        Row() {
          Text('‹')
            .accessibilityText(this.t('返回', 'Back'))
            .fontSize(30)
            .fontColor(this.theme().ink)
            .width(44).height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            // ★ item ④：游戏页最常点的就是它 ⇒ 按下必须"弹一下"（1 → 1.08 → 1）
            .scale({ x: this.backPressed ? IconPress.scale : 1, y: this.backPressed ? IconPress.scale : 1 })
            .animation({ duration: Motion.fast, curve: Motion.snap() })
            .onTouch((e: TouchEvent) => {
              this.backPressed = IconPress.onTouch(this.backPressed, e);
            })
            .onClick(() => {
              Haptics.tap();
              router.back();
            })

          Column({ space: 2 }) {
            Text(this.meta ? displayName(this.meta) : '')
              .fontSize(FontSize.xl)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme().ink)
            Text(this.meta ? displayTagline(this.meta) : '')
              .fontSize(FontSize.xs)
              .fontColor(this.theme().inkFaint)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: Space.md })

          Text(this.fav ? '⭐' : '☆')
            .fontSize(FontSize.lg)
            .fontColor(this.fav ? Palette.amber : this.theme().inkFaint)
            .width(44).height(44).textAlign(TextAlign.Center)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            .animation({ duration: Motion.fast, curve: Motion.spring() })
            .onClick(() => {
              const now: boolean = ProgressStore.toggleFavorite(this.gameId);
              animateTo({ duration: Motion.fast, curve: Motion.spring() }, () => {
                this.fav = now;
              });
            })

          Text('?')
            .accessibilityText(this.t('玩法说明', 'How to play'))
            .fontSize(FontSize.lg)
            .fontColor(this.theme().inkSoft)
            .width(44).height(44).textAlign(TextAlign.Center)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            .margin({ right: Space.sm })
            .onClick(() => {
              Haptics.tap();   // ★ 2026-10-19 按压反馈
              router.pushUrl({ url: 'pages/GuidePage', params: { id: this.gameId } });
            })

          // 难度选择：点一下循环切 简单 → 普通 → 困难
          // ★ 手感：**视觉胶囊保持小巧，但点击热区撑到 44vp**
          //   实测原热区只有 44.3 × 24.0 vp（高度差一半）—— 手指点不准。
          //   做法：外面套一层 44vp 高的 Row 做居中，胶囊本身尺寸/圆角/配色一律不动。
          // ★ 手感：**点击热区 ≥44vp**
          //   实测原热区 44.3 × 24.0 vp（高度差一半，手指点不准）。
          //   ⚠️ 踩过的坑：外面套一层 Row 定高**不生效** ——
          //   `dumpLayout` 报的仍是内部 Text 的尺寸（ArkUI 的命中区跟着最内层文本走）。
          //   ⇒ 必须**直接给 Text 定高**；左右内边距保留，上下内边距去掉（高度已由 height 决定）。
          Text(this.diffLabel())
            .fontSize(FontSize.xxs).fontWeight(FontWeight.Bold)
            .fontColor(this.diffColor())
            .height(Layout.touchMin)
            .textAlign(TextAlign.Center)
            .padding({ left: 12, right: 12 })
            .backgroundColor(this.theme().surfaceAlt)
            .borderRadius(Radius.full)
            .onClick(() => {
              Haptics.tap();
              const next: number = (ProgressStore.diffOf(this.gameId) + 1) % ProgressStore.DIFF_COUNT;
              ProgressStore.setDiff(this.gameId, next);
              this.diffTick = this.diffTick + 1;
              this.nonce = this.nonce + 1;
            })

          Text('↻')
            .accessibilityText(this.t('重新开始', 'Restart'))
            .fontSize(FontSize.xl)
            .fontColor(this.theme().ink)
            .width(44).height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.theme().surface)
            .borderRadius(Radius.full)
            .shadow(Shadow.card)
            .onClick(() => {
              this.nonce = this.nonce + 1;
            })
        }
        .width('100%')
        .padding({ left: Space.lg, right: Space.lg, top: Space.xl, bottom: Space.md })

        // ── 游戏区（直接内联，不走 @Builder）──
        Column() {
          if (this.gameId === 'g2048') {
            if (this.diffTick % 2 === 0) {
              G2048({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              G2048({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'ab_reversal_oddball') {
            if (this.diffTick % 2 === 0) {
              GAbReversalOddball({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAbReversalOddball({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'action_sequence_recall') {
            if (this.diffTick % 2 === 0) {
              GActionSequenceRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GActionSequenceRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'affix_factory') {
            if (this.diffTick % 2 === 0) {
              GAffixFactory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAffixFactory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'akari') {
            if (this.diffTick % 2 === 0) {
              GAkari({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAkari({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'algebraic_balance') {
            if (this.diffTick % 2 === 0) {
              GAlgebraicBalance({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAlgebraicBalance({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'algebraic_inequality_solver') {
            if (this.diffTick % 2 === 0) {
              GAlgebraicInequalitySolver({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAlgebraicInequalitySolver({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'alphabet_sudoku') {
            if (this.diffTick % 2 === 0) {
              GAlphabetSudoku({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAlphabetSudoku({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'anagram_definition') {
            if (this.diffTick % 2 === 0) {
              GAnagramDefinition({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAnagramDefinition({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'angle_finder') {
            if (this.diffTick % 2 === 0) {
              GAngleFinder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAngleFinder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'area_perimeter_match') {
            if (this.diffTick % 2 === 0) {
              GAreaPerimeterMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAreaPerimeterMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'arithmetic_chain') {
            if (this.diffTick % 2 === 0) {
              GArithmeticChain({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GArithmeticChain({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'associative_pairs') {
            if (this.diffTick % 2 === 0) {
              GAssociativePairs({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAssociativePairs({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'attentional_blink') {
            if (this.diffTick % 2 === 0) {
              GAttentionalBlink({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAttentionalBlink({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'attentional_blink_probe') {
            if (this.diffTick % 2 === 0) {
              GAttentionalBlinkProbe({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GAttentionalBlinkProbe({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'balance_scale') {
            if (this.diffTick % 2 === 0) {
              GBalanceScale({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBalanceScale({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'base_conversion_run') {
            if (this.diffTick % 2 === 0) {
              GBaseConversionRun({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBaseConversionRun({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'base_shift') {
            if (this.diffTick % 2 === 0) {
              GBaseShift({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBaseShift({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'bejeweled') {
            if (this.diffTick % 2 === 0) {
              GBejeweled({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBejeweled({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'binary_code') {
            if (this.diffTick % 2 === 0) {
              GBinaryCode({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBinaryCode({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'binary_matrix_rank') {
            if (this.diffTick % 2 === 0) {
              GBinaryMatrixRank({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBinaryMatrixRank({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'binary_matrix_rank_all') {
            if (this.diffTick % 2 === 0) {
              GBinaryMatrixRankAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBinaryMatrixRankAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'binary_puzzle') {
            if (this.diffTick % 2 === 0) {
              GBinaryPuzzle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBinaryPuzzle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'binary_scale_balance') {
            if (this.diffTick % 2 === 0) {
              GBinaryScaleBalance({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBinaryScaleBalance({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'binomial_match') {
            if (this.diffTick % 2 === 0) {
              GBinomialMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBinomialMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'blink_detector') {
            if (this.diffTick % 2 === 0) {
              GBlinkDetector({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBlinkDetector({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'block_count_3d') {
            if (this.diffTick % 2 === 0) {
              GBlockCount3d({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBlockCount3d({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'block_escape') {
            if (this.diffTick % 2 === 0) {
              GBlockEscape({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBlockEscape({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'block_stacking_physics') {
            if (this.diffTick % 2 === 0) {
              GBlockStackingPhysics({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBlockStackingPhysics({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'box_completion') {
            if (this.diffTick % 2 === 0) {
              GBoxCompletion({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBoxCompletion({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'breakout') {
            if (this.diffTick % 2 === 0) {
              GBreakout({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBreakout({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'bridges') {
            if (this.diffTick % 2 === 0) {
              GBridges({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBridges({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'bridges_all') {
            if (this.diffTick % 2 === 0) {
              GBridgesAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBridgesAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'bubble_shooter') {
            if (this.diffTick % 2 === 0) {
              GBubbleShooter({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GBubbleShooter({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'calculation_sprint') {
            if (this.diffTick % 2 === 0) {
              GCalculationSprint({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCalculationSprint({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'card_counting_memory') {
            if (this.diffTick % 2 === 0) {
              GCardCountingMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCardCountingMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'category_fluency') {
            if (this.diffTick % 2 === 0) {
              GCategoryFluency({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCategoryFluency({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'chain_reaction') {
            if (this.diffTick % 2 === 0) {
              GChainReaction({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GChainReaction({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'chalk_and_talk') {
            if (this.diffTick % 2 === 0) {
              GChalkAndTalk({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GChalkAndTalk({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'change_blindness') {
            if (this.diffTick % 2 === 0) {
              GChangeBlindness({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GChangeBlindness({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'checkers') {
            if (this.diffTick % 2 === 0) {
              GCheckers({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCheckers({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'chimp_test') {
            if (this.diffTick % 2 === 0) {
              GChimpTest({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GChimpTest({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'choice_reaction_time') {
            if (this.diffTick % 2 === 0) {
              GChoiceReactionTime({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GChoiceReactionTime({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'circuit_connect') {
            if (this.diffTick % 2 === 0) {
              GCircuitConnect({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCircuitConnect({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'classic_maze') {
            if (this.diffTick % 2 === 0) {
              GClassicMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GClassicMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'cognate_catch') {
            if (this.diffTick % 2 === 0) {
              GCognateCatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCognateCatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'collatz') {
            if (this.diffTick % 2 === 0) {
              GCollatz({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCollatz({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'color_flood') {
            if (this.diffTick % 2 === 0) {
              GColorFlood({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GColorFlood({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'color_match') {
            if (this.diffTick % 2 === 0) {
              GColorMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GColorMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'color_maze_nav') {
            if (this.diffTick % 2 === 0) {
              GColorMazeNav({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GColorMazeNav({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'color_word_match_up') {
            if (this.diffTick % 2 === 0) {
              GColorWordMatchUp({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GColorWordMatchUp({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'common_denominator') {
            if (this.diffTick % 2 === 0) {
              GCommonDenominator({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCommonDenominator({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'compass_maze') {
            if (this.diffTick % 2 === 0) {
              GCompassMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCompassMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'complex_folding_nets') {
            if (this.diffTick % 2 === 0) {
              GComplexFoldingNets({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GComplexFoldingNets({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'compound_connect') {
            if (this.diffTick % 2 === 0) {
              GCompoundConnect({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCompoundConnect({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'conjunction_search') {
            if (this.diffTick % 2 === 0) {
              GConjunctionSearch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GConjunctionSearch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'connect_four') {
            if (this.diffTick % 2 === 0) {
              GConnectFour({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GConnectFour({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'consonant_reconstruct') {
            if (this.diffTick % 2 === 0) {
              GConsonantReconstruct({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GConsonantReconstruct({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'context_clues') {
            if (this.diffTick % 2 === 0) {
              GContextClues({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GContextClues({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'continuous_paired_associate') {
            if (this.diffTick % 2 === 0) {
              GContinuousPairedAssociate({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GContinuousPairedAssociate({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'continuous_recognition') {
            if (this.diffTick % 2 === 0) {
              GContinuousRecognition({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GContinuousRecognition({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'conundrum_anagram') {
            if (this.diffTick % 2 === 0) {
              GConundrumAnagram({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GConundrumAnagram({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'corsi_backward_span') {
            if (this.diffTick % 2 === 0) {
              GCorsiBackwardSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCorsiBackwardSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'corsi_blocks') {
            if (this.diffTick % 2 === 0) {
              GCorsiBlocks({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCorsiBlocks({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'countdown_math') {
            if (this.diffTick % 2 === 0) {
              GCountdownMath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCountdownMath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'counting_sheep') {
            if (this.diffTick % 2 === 0) {
              GCountingSheep({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCountingSheep({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'counting_span') {
            if (this.diffTick % 2 === 0) {
              GCountingSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCountingSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'cross_section_slice') {
            if (this.diffTick % 2 === 0) {
              GCrossSectionSlice({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCrossSectionSlice({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'crossword') {
            if (this.diffTick % 2 === 0) {
              GCrossword({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCrossword({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'crown') {
            if (this.diffTick % 2 === 0) {
              GCrown({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCrown({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'crypto_arithmetic') {
            if (this.diffTick % 2 === 0) {
              GCryptoArithmetic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCryptoArithmetic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'cryptogram') {
            if (this.diffTick % 2 === 0) {
              GCryptogram({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCryptogram({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'cryptogram_all') {
            if (this.diffTick % 2 === 0) {
              GCryptogramAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCryptogramAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'cube_net_fold') {
            if (this.diffTick % 2 === 0) {
              GCubeNetFold({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GCubeNetFold({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'd2_attention') {
            if (this.diffTick % 2 === 0) {
              GD2Attention({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GD2Attention({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'definition_dash') {
            if (this.diffTick % 2 === 0) {
              GDefinitionDash({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDefinitionDash({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'delayed_match_sample') {
            if (this.diffTick % 2 === 0) {
              GDelayedMatchSample({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDelayedMatchSample({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'digit_span_reverse') {
            if (this.diffTick % 2 === 0) {
              GDigitSpanReverse({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDigitSpanReverse({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'digit_swap_eq') {
            if (this.diffTick % 2 === 0) {
              GDigitSwapEq({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDigitSwapEq({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'directions_recall') {
            if (this.diffTick % 2 === 0) {
              GDirectionsRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDirectionsRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'distractor_matrix') {
            if (this.diffTick % 2 === 0) {
              GDistractorMatrix({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDistractorMatrix({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'divided_attention') {
            if (this.diffTick % 2 === 0) {
              GDividedAttention({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDividedAttention({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'divisibility_dash') {
            if (this.diffTick % 2 === 0) {
              GDivisibilityDash({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDivisibilityDash({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'dnms') {
            if (this.diffTick % 2 === 0) {
              GDnms({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDnms({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'dominosa') {
            if (this.diffTick % 2 === 0) {
              GDominosa({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDominosa({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'doodle_jump') {
            if (this.diffTick % 2 === 0) {
              GDoodleJump({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDoodleJump({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'double_n_back') {
            if (this.diffTick % 2 === 0) {
              GDoubleNBack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDoubleNBack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'double_trouble') {
            if (this.diffTick % 2 === 0) {
              GDoubleTrouble({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDoubleTrouble({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'dual_coding') {
            if (this.diffTick % 2 === 0) {
              GDualCoding({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDualCoding({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'dual_mirror') {
            if (this.diffTick % 2 === 0) {
              GDualMirror({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDualMirror({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'dual_task_memory') {
            if (this.diffTick % 2 === 0) {
              GDualTaskMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDualTaskMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'dynamic_salience') {
            if (this.diffTick % 2 === 0) {
              GDynamicSalience({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GDynamicSalience({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'einstein_riddle') {
            if (this.diffTick % 2 === 0) {
              GEinsteinRiddle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GEinsteinRiddle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'etymology_origin') {
            if (this.diffTick % 2 === 0) {
              GEtymologyOrigin({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GEtymologyOrigin({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'etymon_oddball') {
            if (this.diffTick % 2 === 0) {
              GEtymonOddball({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GEtymonOddball({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'event_timeline_memory') {
            if (this.diffTick % 2 === 0) {
              GEventTimelineMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GEventTimelineMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'exponent_tower') {
            if (this.diffTick % 2 === 0) {
              GExponentTower({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GExponentTower({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'face_name_association') {
            if (this.diffTick % 2 === 0) {
              GFaceNameAssociation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFaceNameAssociation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'face_trait_association') {
            if (this.diffTick % 2 === 0) {
              GFaceTraitAssociation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFaceTraitAssociation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'fact_binder') {
            if (this.diffTick % 2 === 0) {
              GFactBinder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFactBinder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'factor_finder') {
            if (this.diffTick % 2 === 0) {
              GFactorFinder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFactorFinder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'feature_matrix_recall') {
            if (this.diffTick % 2 === 0) {
              GFeatureMatrixRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFeatureMatrixRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'feature_matrix_recall_all') {
            if (this.diffTick % 2 === 0) {
              GFeatureMatrixRecallAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFeatureMatrixRecallAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'fibonacci_merge') {
            if (this.diffTick % 2 === 0) {
              GFibonacciMerge({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFibonacciMerge({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'fillomino') {
            if (this.diffTick % 2 === 0) {
              GFillomino({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFillomino({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'find_word') {
            if (this.diffTick % 2 === 0) {
              GFindWord({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFindWord({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'flanker_test') {
            if (this.diffTick % 2 === 0) {
              GFlankerTest({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFlankerTest({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'flappy') {
            if (this.diffTick % 2 === 0) {
              GFlappy({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFlappy({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'focus_tunnel') {
            if (this.diffTick % 2 === 0) {
              GFocusTunnel({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFocusTunnel({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'fraction_match') {
            if (this.diffTick % 2 === 0) {
              GFractionMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFractionMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'fraction_matcher') {
            if (this.diffTick % 2 === 0) {
              GFractionMatcher({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFractionMatcher({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'fractional_pizza') {
            if (this.diffTick % 2 === 0) {
              GFractionalPizza({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFractionalPizza({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'freecell') {
            if (this.diffTick % 2 === 0) {
              GFreecell({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFreecell({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'frequency_tap') {
            if (this.diffTick % 2 === 0) {
              GFrequencyTap({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFrequencyTap({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'futoshiki') {
            if (this.diffTick % 2 === 0) {
              GFutoshiki({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GFutoshiki({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'game24') {
            if (this.diffTick % 2 === 0) {
              GGame24({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGame24({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'gear_rotation') {
            if (this.diffTick % 2 === 0) {
              GGearRotation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGearRotation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'gear_train_direction') {
            if (this.diffTick % 2 === 0) {
              GGearTrainDirection({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGearTrainDirection({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'geometric_vision') {
            if (this.diffTick % 2 === 0) {
              GGeometricVision({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGeometricVision({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'ghost_tap') {
            if (this.diffTick % 2 === 0) {
              GGhostTap({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGhostTap({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'go9') {
            if (this.diffTick % 2 === 0) {
              GGo9({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGo9({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'go_no_go') {
            if (this.diffTick % 2 === 0) {
              GGoNoGo({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGoNoGo({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'gokigen_naname') {
            if (this.diffTick % 2 === 0) {
              GGokigenNaname({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGokigenNaname({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'gomoku') {
            if (this.diffTick % 2 === 0) {
              GGomoku({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGomoku({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'grammar_police') {
            if (this.diffTick % 2 === 0) {
              GGrammarPolice({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGrammarPolice({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'grammar_sort') {
            if (this.diffTick % 2 === 0) {
              GGrammarSort({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGrammarSort({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'graph_coordinate_plot') {
            if (this.diffTick % 2 === 0) {
              GGraphCoordinatePlot({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGraphCoordinatePlot({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'gravity_sort') {
            if (this.diffTick % 2 === 0) {
              GGravitySort({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGravitySort({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'grid_displacement') {
            if (this.diffTick % 2 === 0) {
              GGridDisplacement({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGridDisplacement({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'grocery_list') {
            if (this.diffTick % 2 === 0) {
              GGroceryList({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GGroceryList({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'hanoi') {
            if (this.diffTick % 2 === 0) {
              GHanoi({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GHanoi({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'heyawake') {
            if (this.diffTick % 2 === 0) {
              GHeyawake({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GHeyawake({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'hitori') {
            if (this.diffTick % 2 === 0) {
              GHitori({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GHitori({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'hitori_all') {
            if (this.diffTick % 2 === 0) {
              GHitoriAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GHitoriAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'homophone_hunt') {
            if (this.diffTick % 2 === 0) {
              GHomophoneHunt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GHomophoneHunt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'hue_sort') {
            if (this.diffTick % 2 === 0) {
              GHueSort({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GHueSort({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'inequality_balance_ops') {
            if (this.diffTick % 2 === 0) {
              GInequalityBalanceOps({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GInequalityBalanceOps({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'inequality_dash') {
            if (this.diffTick % 2 === 0) {
              GInequalityDash({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GInequalityDash({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'interlock_puzzle') {
            if (this.diffTick % 2 === 0) {
              GInterlockPuzzle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GInterlockPuzzle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'kakurasu_sums') {
            if (this.diffTick % 2 === 0) {
              GKakurasuSums({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GKakurasuSums({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'kakuro') {
            if (this.diffTick % 2 === 0) {
              GKakuro({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GKakuro({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'kakuro_mini') {
            if (this.diffTick % 2 === 0) {
              GKakuroMini({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GKakuroMini({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'kenken') {
            if (this.diffTick % 2 === 0) {
              GKenken({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GKenken({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'klotski') {
            if (this.diffTick % 2 === 0) {
              GKlotski({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GKlotski({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'kurodoko') {
            if (this.diffTick % 2 === 0) {
              GKurodoko({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GKurodoko({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'laser_link') {
            if (this.diffTick % 2 === 0) {
              GLaserLink({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLaserLink({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'laser_reflect') {
            if (this.diffTick % 2 === 0) {
              GLaserReflect({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLaserReflect({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'letter_bridge') {
            if (this.diffTick % 2 === 0) {
              GLetterBridge({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLetterBridge({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'letter_cancellation') {
            if (this.diffTick % 2 === 0) {
              GLetterCancellation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLetterCancellation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'letter_frequency_scan') {
            if (this.diffTick % 2 === 0) {
              GLetterFrequencyScan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLetterFrequencyScan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'letter_grid_swapper') {
            if (this.diffTick % 2 === 0) {
              GLetterGridSwapper({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLetterGridSwapper({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'life_game') {
            if (this.diffTick % 2 === 0) {
              GLifeGame({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLifeGame({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'lighthouses') {
            if (this.diffTick % 2 === 0) {
              GLighthouses({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLighthouses({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'lights_out') {
            if (this.diffTick % 2 === 0) {
              GLightsOut({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLightsOut({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'lock_pattern') {
            if (this.diffTick % 2 === 0) {
              GLockPattern({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLockPattern({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'logical_syllogisms') {
            if (this.diffTick % 2 === 0) {
              GLogicalSyllogisms({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GLogicalSyllogisms({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'magic_squares') {
            if (this.diffTick % 2 === 0) {
              GMagicSquares({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMagicSquares({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'magnets') {
            if (this.diffTick % 2 === 0) {
              GMagnets({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMagnets({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mahjong_solitaire') {
            if (this.diffTick % 2 === 0) {
              GMahjongSolitaire({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMahjongSolitaire({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mancala') {
            if (this.diffTick % 2 === 0) {
              GMancala({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMancala({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mandala_recall') {
            if (this.diffTick % 2 === 0) {
              GMandalaRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMandalaRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mandelbrot') {
            if (this.diffTick % 2 === 0) {
              GMandelbrot({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMandelbrot({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mastermind') {
            if (this.diffTick % 2 === 0) {
              GMastermind({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMastermind({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'masyu') {
            if (this.diffTick % 2 === 0) {
              GMasyu({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMasyu({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'match3') {
            if (this.diffTick % 2 === 0) {
              GMatch3({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMatch3({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'math_guess') {
            if (this.diffTick % 2 === 0) {
              GMathGuess({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMathGuess({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'math_maze') {
            if (this.diffTick % 2 === 0) {
              GMathMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMathMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'math_path') {
            if (this.diffTick % 2 === 0) {
              GMathPath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMathPath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'matrix_multiplier') {
            if (this.diffTick % 2 === 0) {
              GMatrixMultiplier({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMatrixMultiplier({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'matrix_multiplier_match') {
            if (this.diffTick % 2 === 0) {
              GMatrixMultiplierMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMatrixMultiplierMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'matrix_reasoning') {
            if (this.diffTick % 2 === 0) {
              GMatrixReasoning({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMatrixReasoning({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'maze_nav_3d') {
            if (this.diffTick % 2 === 0) {
              GMazeNav3d({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMazeNav3d({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'memory') {
            if (this.diffTick % 2 === 0) {
              GMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'memory_matrix') {
            if (this.diffTick % 2 === 0) {
              GMemoryMatrix({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMemoryMatrix({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'memory_palace') {
            if (this.diffTick % 2 === 0) {
              GMemoryPalace({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMemoryPalace({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mental_abacus') {
            if (this.diffTick % 2 === 0) {
              GMentalAbacus({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMentalAbacus({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mental_calendar') {
            if (this.diffTick % 2 === 0) {
              GMentalCalendar({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMentalCalendar({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mental_mapping') {
            if (this.diffTick % 2 === 0) {
              GMentalMapping({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMentalMapping({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mental_rotation') {
            if (this.diffTick % 2 === 0) {
              GMentalRotation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMentalRotation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'minesweeper') {
            if (this.diffTick % 2 === 0) {
              GMinesweeper({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMinesweeper({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mirror_image') {
            if (this.diffTick % 2 === 0) {
              GMirrorImage({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMirrorImage({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mirror_maze') {
            if (this.diffTick % 2 === 0) {
              GMirrorMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMirrorMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'mirror_tracing') {
            if (this.diffTick % 2 === 0) {
              GMirrorTracing({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMirrorTracing({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'missing_operator') {
            if (this.diffTick % 2 === 0) {
              GMissingOperator({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMissingOperator({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'missing_vowels') {
            if (this.diffTick % 2 === 0) {
              GMissingVowels({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMissingVowels({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'modular_clock_arithmetic') {
            if (this.diffTick % 2 === 0) {
              GModularClockArithmetic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GModularClockArithmetic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'modulo_clock') {
            if (this.diffTick % 2 === 0) {
              GModuloClock({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GModuloClock({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'modulo_path') {
            if (this.diffTick % 2 === 0) {
              GModuloPath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GModuloPath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'multi_track_counter') {
            if (this.diffTick % 2 === 0) {
              GMultiTrackCounter({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMultiTrackCounter({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'multiple_object_tracking') {
            if (this.diffTick % 2 === 0) {
              GMultipleObjectTracking({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GMultipleObjectTracking({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'n_back') {
            if (this.diffTick % 2 === 0) {
              GNBack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNBack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'narrative_recall') {
            if (this.diffTick % 2 === 0) {
              GNarrativeRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNarrativeRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'navon_hierarchical') {
            if (this.diffTick % 2 === 0) {
              GNavonHierarchical({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNavonHierarchical({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'negative_space_detection') {
            if (this.diffTick % 2 === 0) {
              GNegativeSpaceDetection({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNegativeSpaceDetection({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'nim') {
            if (this.diffTick % 2 === 0) {
              GNim({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNim({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'nonogram') {
            if (this.diffTick % 2 === 0) {
              GNonogram({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNonogram({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'norinori') {
            if (this.diffTick % 2 === 0) {
              GNoriNori({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNoriNori({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'number_bonds') {
            if (this.diffTick % 2 === 0) {
              GNumberBonds({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNumberBonds({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'number_bonds_all') {
            if (this.diffTick % 2 === 0) {
              GNumberBondsAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNumberBondsAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'numerical_estimation') {
            if (this.diffTick % 2 === 0) {
              GNumericalEstimation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNumericalEstimation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'nurikabe') {
            if (this.diffTick % 2 === 0) {
              GNurikabe({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GNurikabe({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'object_displacement') {
            if (this.diffTick % 2 === 0) {
              GObjectDisplacement({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GObjectDisplacement({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'object_shuffle') {
            if (this.diffTick % 2 === 0) {
              GObjectShuffle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GObjectShuffle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'odd_even_flash') {
            if (this.diffTick % 2 === 0) {
              GOddEvenFlash({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GOddEvenFlash({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'odd_one_out') {
            if (this.diffTick % 2 === 0) {
              GOddOneOut({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GOddOneOut({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'odd_rotation') {
            if (this.diffTick % 2 === 0) {
              GOddRotation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GOddRotation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'one_letter_shift') {
            if (this.diffTick % 2 === 0) {
              GOneLetterShift({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GOneLetterShift({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'operation_span') {
            if (this.diffTick % 2 === 0) {
              GOperationSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GOperationSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'orbit_tap') {
            if (this.diffTick % 2 === 0) {
              GOrbitTap({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GOrbitTap({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'oxymoron_hunt') {
            if (this.diffTick % 2 === 0) {
              GOxymoronHunt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GOxymoronHunt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'palindrome_builder') {
            if (this.diffTick % 2 === 0) {
              GPalindromeBuilder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPalindromeBuilder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'pangram_sprint') {
            if (this.diffTick % 2 === 0) {
              GPangramSprint({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPangramSprint({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'paper_folding') {
            if (this.diffTick % 2 === 0) {
              GPaperFolding({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPaperFolding({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'path_finder') {
            if (this.diffTick % 2 === 0) {
              GPathFinder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPathFinder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'path_intersect') {
            if (this.diffTick % 2 === 0) {
              GPathIntersect({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPathIntersect({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'path_recall') {
            if (this.diffTick % 2 === 0) {
              GPathRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPathRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'pattern_sequence_draw') {
            if (this.diffTick % 2 === 0) {
              GPatternSequenceDraw({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPatternSequenceDraw({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'peg_solitaire') {
            if (this.diffTick % 2 === 0) {
              GPegSolitaire({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPegSolitaire({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'percentage_peak') {
            if (this.diffTick % 2 === 0) {
              GPercentagePeak({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPercentagePeak({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'percentage_shopping') {
            if (this.diffTick % 2 === 0) {
              GPercentageShopping({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPercentageShopping({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'peripheral_focus') {
            if (this.diffTick % 2 === 0) {
              GPeripheralFocus({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPeripheralFocus({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'perspective_shift_view') {
            if (this.diffTick % 2 === 0) {
              GPerspectiveShiftView({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPerspectiveShiftView({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'perspective_taking') {
            if (this.diffTick % 2 === 0) {
              GPerspectiveTaking({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPerspectiveTaking({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'phonetic_guess') {
            if (this.diffTick % 2 === 0) {
              GPhoneticGuess({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPhoneticGuess({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'pipes') {
            if (this.diffTick % 2 === 0) {
              GPipes({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPipes({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'pixel_mimic') {
            if (this.diffTick % 2 === 0) {
              GPixelMimic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPixelMimic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'polyomino_tiling') {
            if (this.diffTick % 2 === 0) {
              GPolyominoTiling({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPolyominoTiling({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'pong') {
            if (this.diffTick % 2 === 0) {
              GPong({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPong({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'portmanteau_split') {
            if (this.diffTick % 2 === 0) {
              GPortmanteauSplit({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPortmanteauSplit({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'posner_spatial_cueing') {
            if (this.diffTick % 2 === 0) {
              GPosnerSpatialCueing({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPosnerSpatialCueing({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'prime_factor_trees') {
            if (this.diffTick % 2 === 0) {
              GPrimeFactorTrees({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPrimeFactorTrees({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'prime_gap_hunt') {
            if (this.diffTick % 2 === 0) {
              GPrimeGapHunt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPrimeGapHunt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'prime_hunter') {
            if (this.diffTick % 2 === 0) {
              GPrimeHunter({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPrimeHunter({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'probe_digit_span') {
            if (this.diffTick % 2 === 0) {
              GProbeDigitSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GProbeDigitSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'pythagorean_triple_builder') {
            if (this.diffTick % 2 === 0) {
              GPythagoreanTripleBuilder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GPythagoreanTripleBuilder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'quick_math') {
            if (this.diffTick % 2 === 0) {
              GQuickMath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GQuickMath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'radical_roots') {
            if (this.diffTick % 2 === 0) {
              GRadicalRoots({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRadicalRoots({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'reading_span') {
            if (this.diffTick % 2 === 0) {
              GReadingSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GReadingSpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'reflex_tap') {
            if (this.diffTick % 2 === 0) {
              GReflexTap({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GReflexTap({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'relational_memory') {
            if (this.diffTick % 2 === 0) {
              GRelationalMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRelationalMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'reverse_stroop') {
            if (this.diffTick % 2 === 0) {
              GReverseStroop({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GReverseStroop({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'reversi') {
            if (this.diffTick % 2 === 0) {
              GReversi({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GReversi({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'rhyme_master') {
            if (this.diffTick % 2 === 0) {
              GRhymeMaster({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRhymeMaster({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'rhythm_master') {
            if (this.diffTick % 2 === 0) {
              GRhythmMaster({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRhythmMaster({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'roman_arithmetic') {
            if (this.diffTick % 2 === 0) {
              GRomanArithmetic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRomanArithmetic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'room_inspector') {
            if (this.diffTick % 2 === 0) {
              GRoomInspector({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRoomInspector({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'rotating_maze') {
            if (this.diffTick % 2 === 0) {
              GRotatingMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRotatingMaze({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'rule_switcher') {
            if (this.diffTick % 2 === 0) {
              GRuleSwitcher({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRuleSwitcher({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'running_memory_span') {
            if (this.diffTick % 2 === 0) {
              GRunningMemorySpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GRunningMemorySpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'schulte') {
            if (this.diffTick % 2 === 0) {
              GSchulte({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSchulte({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sdmt') {
            if (this.diffTick % 2 === 0) {
              GSdmt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSdmt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'semantic_association') {
            if (this.diffTick % 2 === 0) {
              GSemanticAssociation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSemanticAssociation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'semantic_distance') {
            if (this.diffTick % 2 === 0) {
              GSemanticDistance({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSemanticDistance({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'semantic_link') {
            if (this.diffTick % 2 === 0) {
              GSemanticLink({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSemanticLink({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sentence_unscramble') {
            if (this.diffTick % 2 === 0) {
              GSentenceUnscramble({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSentenceUnscramble({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sequence_sleuth') {
            if (this.diffTick % 2 === 0) {
              GSequenceSleuth({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSequenceSleuth({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sequence_stack') {
            if (this.diffTick % 2 === 0) {
              GSequenceStack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSequenceStack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'set_theory_venn') {
            if (this.diffTick % 2 === 0) {
              GSetTheoryVenn({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSetTheoryVenn({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'shadow_pivot') {
            if (this.diffTick % 2 === 0) {
              GShadowPivot({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GShadowPivot({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'shape_shifter') {
            if (this.diffTick % 2 === 0) {
              GShapeShifter({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GShapeShifter({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'shell_game') {
            if (this.diffTick % 2 === 0) {
              GShellGame({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GShellGame({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'shikaku') {
            if (this.diffTick % 2 === 0) {
              GShikaku({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GShikaku({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sieve_visualizer') {
            if (this.diffTick % 2 === 0) {
              GSieveVisualizer({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSieveVisualizer({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'silent_letter_search') {
            if (this.diffTick % 2 === 0) {
              GSilentLetterSearch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSilentLetterSearch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'silhouette_match') {
            if (this.diffTick % 2 === 0) {
              GSilhouetteMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSilhouetteMatch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'silhouette_match_ortho') {
            if (this.diffTick % 2 === 0) {
              GSilhouetteMatchOrtho({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSilhouetteMatchOrtho({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'simon_command') {
            if (this.diffTick % 2 === 0) {
              GSimonCommand({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSimonCommand({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'simon_says') {
            if (this.diffTick % 2 === 0) {
              GSimonSays({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSimonSays({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'simon_sequence') {
            if (this.diffTick % 2 === 0) {
              GSimonSequence({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSimonSequence({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'skyscrapers') {
            if (this.diffTick % 2 === 0) {
              GSkyscrapers({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSkyscrapers({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'slide15') {
            if (this.diffTick % 2 === 0) {
              GSlide15({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSlide15({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'slide_puzzle') {
            if (this.diffTick % 2 === 0) {
              GSlidePuzzle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSlidePuzzle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'slitherlink') {
            if (this.diffTick % 2 === 0) {
              GSlitherlink({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSlitherlink({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'snake') {
            if (this.diffTick % 2 === 0) {
              GSnake({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSnake({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'snake_3d') {
            if (this.diffTick % 2 === 0) {
              GSnake3D({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSnake3D({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sokoban') {
            if (this.diffTick % 2 === 0) {
              GSokoban({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSokoban({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'solitaire') {
            if (this.diffTick % 2 === 0) {
              GSolitaire({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSolitaire({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sopt') {
            if (this.diffTick % 2 === 0) {
              GSopt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSopt({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sorting_visualizer') {
            if (this.diffTick % 2 === 0) {
              GSortingVisualizer({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSortingVisualizer({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'source_monitoring') {
            if (this.diffTick % 2 === 0) {
              GSourceMonitoring({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSourceMonitoring({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'spatial_cabinet_memory') {
            if (this.diffTick % 2 === 0) {
              GSpatialCabinetMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSpatialCabinetMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'spatial_conflict') {
            if (this.diffTick % 2 === 0) {
              GSpatialConflict({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSpatialConflict({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'spelling_sprint') {
            if (this.diffTick % 2 === 0) {
              GSpellingSprint({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSpellingSprint({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'spider_solitaire') {
            if (this.diffTick % 2 === 0) {
              GSpiderSolitaire({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSpiderSolitaire({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'spoonerism_solver') {
            if (this.diffTick % 2 === 0) {
              GSpoonerismSolver({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSpoonerismSolver({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'spotlight_track') {
            if (this.diffTick % 2 === 0) {
              GSpotlightTrack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSpotlightTrack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'staircase_memory') {
            if (this.diffTick % 2 === 0) {
              GStaircaseMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GStaircaseMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sternberg_task') {
            if (this.diffTick % 2 === 0) {
              GSternbergTask({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSternbergTask({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'stop_signal') {
            if (this.diffTick % 2 === 0) {
              GStopSignal({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GStopSignal({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'story_builder') {
            if (this.diffTick % 2 === 0) {
              GStoryBuilder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GStoryBuilder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'stroop_number_size') {
            if (this.diffTick % 2 === 0) {
              GStroopNumberSize({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GStroopNumberSize({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'stroop_test') {
            if (this.diffTick % 2 === 0) {
              GStroopTest({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GStroopTest({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'subitizing_rush') {
            if (this.diffTick % 2 === 0) {
              GSubitizingRush({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSubitizingRush({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sudoku') {
            if (this.diffTick % 2 === 0) {
              GSudoku({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSudoku({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sudoku_hex') {
            if (this.diffTick % 2 === 0) {
              GSudokuHex({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSudokuHex({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sum_pyramid') {
            if (this.diffTick % 2 === 0) {
              GSumPyramid({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSumPyramid({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'sum_snake') {
            if (this.diffTick % 2 === 0) {
              GSumSnake({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSumSnake({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'switch_task') {
            if (this.diffTick % 2 === 0) {
              GSwitchTask({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSwitchTask({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'syllable_stack') {
            if (this.diffTick % 2 === 0) {
              GSyllableStack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSyllableStack({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'symbol_digit_assoc') {
            if (this.diffTick % 2 === 0) {
              GSymbolDigitAssoc({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSymbolDigitAssoc({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'symbol_logic') {
            if (this.diffTick % 2 === 0) {
              GSymbolLogic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSymbolLogic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'symbolic_flanker') {
            if (this.diffTick % 2 === 0) {
              GSymbolicFlanker({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSymbolicFlanker({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'symmetry') {
            if (this.diffTick % 2 === 0) {
              GSymmetry({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSymmetry({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'symmetry_span') {
            if (this.diffTick % 2 === 0) {
              GSymmetrySpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GSymmetrySpan({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tangle_fix') {
            if (this.diffTick % 2 === 0) {
              GTangleFix({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTangleFix({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tangram') {
            if (this.diffTick % 2 === 0) {
              GTangram({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTangram({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tapa') {
            if (this.diffTick % 2 === 0) {
              GTapa({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTapa({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'target_10') {
            if (this.diffTick % 2 === 0) {
              GTarget10({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTarget10({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'target_number') {
            if (this.diffTick % 2 === 0) {
              GTargetNumber({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTargetNumber({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'task_switching') {
            if (this.diffTick % 2 === 0) {
              GTaskSwitching({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTaskSwitching({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'temporal_order') {
            if (this.diffTick % 2 === 0) {
              GTemporalOrder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTemporalOrder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'temporal_order_judgment') {
            if (this.diffTick % 2 === 0) {
              GTemporalOrderJudgment({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTemporalOrderJudgment({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tenner_grid') {
            if (this.diffTick % 2 === 0) {
              GTennerGrid({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTennerGrid({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tents_and_trees') {
            if (this.diffTick % 2 === 0) {
              GTentsAndTrees({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTentsAndTrees({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tetris') {
            if (this.diffTick % 2 === 0) {
              GTetris({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTetris({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tic_tac_toe') {
            if (this.diffTick % 2 === 0) {
              GTicTacToe({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTicTacToe({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'topology') {
            if (this.diffTick % 2 === 0) {
              GTopology({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTopology({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tower_of_hanoi') {
            if (this.diffTick % 2 === 0) {
              GTowerOfHanoi({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTowerOfHanoi({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'tower_of_london') {
            if (this.diffTick % 2 === 0) {
              GTowerOfLondon({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTowerOfLondon({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'trace_path') {
            if (this.diffTick % 2 === 0) {
              GTracePath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTracePath({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'trail_making') {
            if (this.diffTick % 2 === 0) {
              GTrailMaking({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTrailMaking({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'triple_sequence') {
            if (this.diffTick % 2 === 0) {
              GTripleSequence({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTripleSequence({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'triplets_logic') {
            if (this.diffTick % 2 === 0) {
              GTripletsLogic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTripletsLogic({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'typing_speed') {
            if (this.diffTick % 2 === 0) {
              GTypingSpeed({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTypingSpeed({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'typoglycemia_decoder') {
            if (this.diffTick % 2 === 0) {
              GTypoglycemiaDecoder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GTypoglycemiaDecoder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'unit_converter_pro') {
            if (this.diffTick % 2 === 0) {
              GUnitConverterPro({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GUnitConverterPro({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'vector_dot_product') {
            if (this.diffTick % 2 === 0) {
              GVectorDotProduct({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVectorDotProduct({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'vector_grid_alignment') {
            if (this.diffTick % 2 === 0) {
              GVectorGridAlignment({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVectorGridAlignment({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'vektor_vector') {
            if (this.diffTick % 2 === 0) {
              GVektorVector({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVektorVector({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'venn_numbers') {
            if (this.diffTick % 2 === 0) {
              GVennNumbers({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVennNumbers({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'verbal_analogies') {
            if (this.diffTick % 2 === 0) {
              GVerbalAnalogies({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVerbalAnalogies({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'vigilance_task') {
            if (this.diffTick % 2 === 0) {
              GVigilanceTask({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVigilanceTask({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'visual_crowding_acuity') {
            if (this.diffTick % 2 === 0) {
              GVisualCrowdingAcuity({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVisualCrowdingAcuity({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'visual_search') {
            if (this.diffTick % 2 === 0) {
              GVisualSearch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVisualSearch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'visual_search_all') {
            if (this.diffTick % 2 === 0) {
              GVisualSearchAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVisualSearchAll({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'visual_search_conjunction') {
            if (this.diffTick % 2 === 0) {
              GVisualSearchConjunction({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVisualSearchConjunction({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'visual_statistical_learning') {
            if (this.diffTick % 2 === 0) {
              GVisualStatisticalLearning({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVisualStatisticalLearning({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'vocabulary_builder') {
            if (this.diffTick % 2 === 0) {
              GVocabularyBuilder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVocabularyBuilder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'vowel_reconstruct') {
            if (this.diffTick % 2 === 0) {
              GVowelReconstruct({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GVowelReconstruct({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'water_sort') {
            if (this.diffTick % 2 === 0) {
              GWaterSort({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWaterSort({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'wireframe_3d_rotation') {
            if (this.diffTick % 2 === 0) {
              GWireframe3dRotation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWireframe3dRotation({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'wisconsin_card_sorting') {
            if (this.diffTick % 2 === 0) {
              GWisconsinCardSorting({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWisconsinCardSorting({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_association_recall') {
            if (this.diffTick % 2 === 0) {
              GWordAssociationRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordAssociationRecall({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_grid_connection') {
            if (this.diffTick % 2 === 0) {
              GWordGridConnection({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordGridConnection({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_ladder') {
            if (this.diffTick % 2 === 0) {
              GWordLadder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordLadder({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_ladder_step') {
            if (this.diffTick % 2 === 0) {
              GWordLadderStep({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordLadderStep({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_mastermind') {
            if (this.diffTick % 2 === 0) {
              GWordMastermind({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordMastermind({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_pair_associate_memory') {
            if (this.diffTick % 2 === 0) {
              GWordPairAssociateMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordPairAssociateMemory({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_scramble') {
            if (this.diffTick % 2 === 0) {
              GWordScramble({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordScramble({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_search') {
            if (this.diffTick % 2 === 0) {
              GWordSearch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordSearch({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_snake_trail') {
            if (this.diffTick % 2 === 0) {
              GWordSnakeTrail({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordSnakeTrail({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_surge') {
            if (this.diffTick % 2 === 0) {
              GWordSurge({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordSurge({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'word_wheel') {
            if (this.diffTick % 2 === 0) {
              GWordWheel({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordWheel({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'wordle') {
            if (this.diffTick % 2 === 0) {
              GWordle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GWordle({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else if (this.gameId === 'yajilin') {
            if (this.diffTick % 2 === 0) {
              GYajilin({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            } else {
              GYajilin({ theme: this.theme(), restartToken: this.nonce, onFinish: (r) => this.handleFinish(r) })
            }
          } else {
            this.placeholder()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: Space.lg, right: Space.lg, bottom: Space.lg })
      }
      .width('100%')
      .height('100%')

      // ── 结算弹窗 ──
      if (this.showResult) {
        Column({ space: Space.md }) {
          Text(this.lastSolved ? '🎉' : '💪')
            .fontSize(44)
            .scale({ x: this.pop ? 1 : 0.4, y: this.pop ? 1 : 0.4 })
            .rotate({ angle: this.pop ? 0 : -18 })
            .animation({ duration: 480, curve: Motion.snap() })
          Text(this.lastSolved ? this.t('这一局拿下！', 'You cleared it!') : this.t('再来一局？', 'One more?'))
            .fontSize(FontSize.xl).fontWeight(FontWeight.Bold)
            .fontColor(this.theme().ink)
          // ★ 手感：刚解锁的成就**当场亮出来** + 三连庆祝（大时刻）
          if (this.newAch.length > 0) {
            Column({ space: 4 }) {
              ForEach(this.newAch, (a: string) => {
                Text(this.t('🏆 解锁成就 ', '🏆 Unlocked ') + a)
                  .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
                  .fontColor(Palette.amber)
              }, (a: string) => a)
            }
            .width('100%')
            .padding({ left: Space.md, right: Space.md, top: 8, bottom: 8 })
            .backgroundColor('#1AF59E0B')
            .borderRadius(Radius.md)
            .scale({ x: this.pop ? 1 : 0.8, y: this.pop ? 1 : 0.8 })
            .opacity(this.pop ? 1 : 0)
            .animation({ duration: Motion.base, curve: Motion.snap(), delay: 120 })
          }
          if (this.levelUpTo > 0) {
            Row({ space: Space.sm }) {
              Text('🎊').accessibilityLevel('no').fontSize(FontSize.lg)
              Text(this.t('升到 LV ', 'Reached LV ') + this.levelUpTo + ' · ' + ProgressStore.titleOf(this.levelUpTo))
                .fontSize(FontSize.sm).fontWeight(FontWeight.Bold)
                .fontColor(Palette.amber)
            }
            .padding({ left: Space.md, right: Space.md, top: 6, bottom: 6 })
            .backgroundColor('#1AF59E0B')
            .borderRadius(Radius.full)
            .scale({ x: this.pop ? 1 : 0.7, y: this.pop ? 1 : 0.7 })
            .opacity(this.pop ? 1 : 0)
            .animation({ duration: Motion.base, curve: Motion.snap(), delay: 220 })
          }

          // ★ 手感：得分与经验**滚动计数**（从 0 数到最终值）
          //   ⚠️ 必须内联 Text 读 @State —— this.stat(...) 是 @Builder，
          //   它的参数不建立 ArkUI 观察，计数过程中不会刷新（这个坑真踩过）
          Row({ space: Space.xl }) {
            Column({ space: 2 }) {
              Text(Digits(String(this.scoreShown), this.langCode)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
                .fontColor(this.theme().ink)
              Text(this.t('得分', 'Score')).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
            }.layoutWeight(1)
            .opacity(this.pop ? 1 : 0).translate({ y: this.pop ? 0 : 10 })
            .animation({ duration: Motion.base, curve: Motion.spring() })
            Column({ space: 2 }) {
              Text((this.lastMs / 1000).toFixed(1) + 's').fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
                .fontColor(this.theme().ink)
              Text(this.t('用时', 'Time')).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
            }.layoutWeight(1)
            .opacity(this.pop ? 1 : 0).translate({ y: this.pop ? 0 : 10 })
            .animation({ duration: Motion.base, curve: Motion.spring(), delay: 80 })
            Column({ space: 2 }) {
              Text('+' + String(this.gainShown)).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
                .fontColor(Palette.emerald)
              Text(this.t('经验', 'XP')).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
            }.layoutWeight(1)
            .opacity(this.pop ? 1 : 0).translate({ y: this.pop ? 0 : 10 })
            .animation({ duration: Motion.base, curve: Motion.spring(), delay: 160 })
          }
          Button(this.t('再来一局', 'Play again'))
            .fontSize(FontSize.md)
            .fontColor(Color.White)
            .backgroundColor(this.accentColor())
            .borderRadius(Radius.md)
            // ★ 2026-10-19 自查 A3：结算页主按钮写死 46vp，大字模式字会顶出去
            .width('100%').constraintSize({ minHeight: Cell.of(46) })
            .onClick(() => {
              Haptics.tap();   // ★ 2026-10-19 按压反馈
              animateTo({ duration: Motion.fast, curve: Motion.spring() }, () => {
                this.showResult = false;
                this.nonce = this.nonce + 1;
              });
            })
          Button(this.t('返回列表', 'Back to list'))
            .fontSize(FontSize.md)
            .fontColor(this.theme().inkSoft)
            .backgroundColor(this.theme().surfaceAlt)
            .borderRadius(Radius.md)
            .width('100%').height(46)
            .onClick(() => {
              router.back();
            })
        }
        .width('100%')
        .padding(Space.xxl)
        .backgroundColor(this.theme().surface)
        .borderRadius({ topLeft: Radius.xl, topRight: Radius.xl })
        .shadow(Shadow.card)
        .transition(TransitionEffect.OPACITY.animation({ duration: Motion.sheet })
          .combine(TransitionEffect.translate({ y: 300 })))
      }

      // ★★★「动画拉满」胜利粒子层
      //   放在结算弹窗【之后】⇒ 盖在最上面；绝对定位 + markAnchor ⇒ 不影响任何布局
      //   中心点 (50%, 72%) ≈ 结算弹窗里那个 🎉 的位置 ⇒ 粒子看起来是"从 🎉 炸出来的"
      if (this.showResult && this.lastSolved) {
        SparkBurst({ progress: this.burstP, count: 26, spread: 175 })
          .width(420)
          .height(420)
          // ★ 纵向锚点随界面模式算（见 burstY 的注释）
          .position({ x: '50%', y: this.burstY() })
          .markAnchor({ x: 210, y: 210 })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme().bg)
    // ★ 动画 ①：与首页那张 GameCard 配对（同名 id）—— 卡片"长大"成整页。
    //   用 `sharedTransition`（跨页面）而不是 `geometryTransition`（同页一对），见 Common.ets 的注释。
    .sharedTransition(this.sharedId, {
      // ★★★ 2026-10-14 奥森反馈「每个小游戏的开启动画非常诡异」⇒ 修：
      //   整页容器用 `Exchange` ⇒ 整页内容从"卡片尺寸"拉伸到全屏 ⇒ 文字拉扁、按钮变形
      //   改为 `Static`：★ 只平移、不改尺寸 ⇒ 页面干净滑入 ✓
      duration: Motion.base,
      curve: Curve.Friction,
      type: SharedTransitionEffectType.Static
    })
  }

  @Builder
  stat(label: string, value: string, delay: number) {
    Column({ space: 2 }) {
      Text(value).fontSize(FontSize.lg).fontWeight(FontWeight.Bold)
        .fontColor(this.theme().ink)
      Text(label).fontSize(FontSize.xxs).fontColor(this.theme().inkFaint)
    }
    .opacity(this.pop ? 1 : 0)
    .translate({ y: this.pop ? 0 : 10 })
    .animation({ duration: Motion.base, curve: Motion.spring(), delay: delay })
  }
}
