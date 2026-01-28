// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get settingsTitle => '설정';

  @override
  String get appearanceSectionTitle => '외관';

  @override
  String get themeLabel => '테마';

  @override
  String get themeSubtitleSystem => '시스템 기본값';

  @override
  String get themeOptionSystem => '시스템';

  @override
  String get themeOptionLight => '라이트';

  @override
  String get themeOptionDark => '다크';

  @override
  String get languageLabel => '언어';

  @override
  String get languageSubtitle => '애플리케이션 언어 선택';

  @override
  String get languageOptionEnglish => '영어';

  @override
  String get languageOptionTurkish => '터키어';

  @override
  String get languageOptionSpanish => '스페인어';

  @override
  String get languageOptionPortuguese => '포르투갈어';

  @override
  String get languageOptionHindi => '힌디어';

  @override
  String get languageOptionChinese => '중국어';

  @override
  String get languageOptionArabic => '아랍어';

  @override
  String get languageOptionFrench => '프랑스어';

  @override
  String get languageOptionGerman => '독일어';

  @override
  String get languageOptionRussian => '러시아어';

  @override
  String get languageOptionJapanese => '일본어';

  @override
  String get languageOptionKorean => '한국어';

  @override
  String get performanceSectionTitle => '성능 및 캐시';

  @override
  String get clearVisualizerCacheTitle => '비주얼라이저 캐시 삭제';

  @override
  String get clearVisualizerCacheSubtitle => '미리 계산된 FFT 데이터 삭제';

  @override
  String get clearVisualizerCacheSnack => '비주얼라이저 캐시가 삭제되었습니다';

  @override
  String get clearAudioReactiveCacheTitle => '오디오 반응형 캐시 삭제';

  @override
  String get clearAudioReactiveCacheSubtitle => '캐시된 FFT 데이터 삭제';

  @override
  String get clearAudioReactiveCacheSnack => '오디오 반응형 캐시가 삭제되었습니다';

  @override
  String get advancedSectionTitle => '고급';

  @override
  String get resetSettingsTitle => '설정을 기본값으로 재설정';

  @override
  String get resetSettingsSubtitle => '전체 설정 복원';

  @override
  String get resetSettingsSnack => '설정이 기본값으로 재설정되었습니다';

  @override
  String get projectListTitle => '내 프로젝트';

  @override
  String get projectListEmpty => '아직 프로젝트가 없습니다';

  @override
  String get projectListNewProject => '새 프로젝트';

  @override
  String get projectListContinueEditing => '편집 계속하기';

  @override
  String get projectListDefaultHeadline => '전문가용 에디터';

  @override
  String get projectMenuDesign => '디자인';

  @override
  String get projectMenuEditInfo => '정보 수정';

  @override
  String get projectMenuVideos => '비디오';

  @override
  String get projectMenuDelete => '삭제';

  @override
  String get projectDeleteDialogTitle => '삭제 확인';

  @override
  String get projectDeleteDialogMessage => '이 프로젝트를 삭제하시겠습니까?';

  @override
  String get commonCancel => '취소';

  @override
  String get commonDelete => '삭제';

  @override
  String get commonOk => '확인';

  @override
  String get projectEditAppBarNew => '새 프로젝트';

  @override
  String get projectEditAppBarEdit => '프로젝트 편집';

  @override
  String get projectEditTitleHint => '프로젝트 제목 입력';

  @override
  String get projectEditTitleValidation => '제목을 입력해주세요';

  @override
  String get projectEditDescriptionHint => '설명 추가 (선택 사항)';

  @override
  String get projectEditCreateButton => '프로젝트 생성';

  @override
  String get projectEditSaveButton => '변경 사항 저장';

  @override
  String get directorMissingAssetsTitle => '일부 에셋이 삭제되었습니다';

  @override
  String get directorMissingAssetsMessage =>
      '계속하려면 기기에서 삭제된 에셋을 복구하거나 타임라인에서 제거해야 합니다(빨간색으로 표시됨).';

  @override
  String get editorHeaderCloseTooltip => '닫기';

  @override
  String get editorHeaderArchiveTooltip => '프로젝트 가져오기/내보내기 (.vvz)';

  @override
  String get editorHeaderViewGeneratedTooltip => '생성된 비디오 보기';

  @override
  String get editorHeaderExportTooltip => '비디오 내보내기';

  @override
  String get editorHeaderAddVideoFirstTooltip => '비디오를 먼저 추가하세요';

  @override
  String get editorGenerateTooltip => '비디오 생성';

  @override
  String get editorGenerateFullHdLabel => 'Full HD 1080p 생성';

  @override
  String get editorGenerateHdLabel => 'HD 720p 생성';

  @override
  String get editorGenerateSdLabel => 'SD 360p 생성';

  @override
  String get exportSheetTitle => '비디오 내보내기';

  @override
  String get exportSheetResolutionLabel => '해상도';

  @override
  String get exportSheetResolutionHelp => '높은 해상도: 대화면에서 선명한 재생';

  @override
  String get exportSheetFileFormatLabel => '파일 형식';

  @override
  String get exportSheetFpsLabel => '초당 프레임 수 (FPS)';

  @override
  String get exportSheetFpsHelp => '프레임 레이트가 높을수록 애니메이션이 부드러워집니다';

  @override
  String get exportSheetQualityLabel => '화질 / 비트레이트';

  @override
  String get exportSheetQualityLow => '낮음';

  @override
  String get exportSheetQualityMedium => '중간';

  @override
  String get exportSheetQualityHigh => '높음';

  @override
  String get exportSheetButtonExport => '비디오 내보내기';

  @override
  String get videoRes8k => '8K UHD 4320p';

  @override
  String get videoRes6k => '6K UHD 3456p';

  @override
  String get videoRes4k => '4K UHD 2160p';

  @override
  String get videoRes2k => '2K QHD 1440p';

  @override
  String get videoResFullHd => 'Full HD 1080p';

  @override
  String get videoResHd => 'HD 720p';

  @override
  String get videoResSd => 'SD 360p';

  @override
  String get videoQualityUltra => '울트라 화질';

  @override
  String get videoQualityStandard => '표준 화질';

  @override
  String get exportLegacyViewVideos => '비디오 보기';

  @override
  String get exportProgressPreprocessingTitle => '파일 전처리 중';

  @override
  String get exportProgressBuildingTitle => '비디오 생성 중';

  @override
  String get exportProgressSavedTitle => '비디오가 갤러리에 저장되었습니다';

  @override
  String get exportProgressErrorTitle => '오류';

  @override
  String get exportProgressErrorMessage =>
      '예기치 않은 오류가 발생했습니다. 문제를 해결 중입니다. 다시 시도하거나 오류가 지속되면 앱을 최신 버전으로 업데이트해주세요.';

  @override
  String exportProgressFileOfTotal(int current, int total) {
    return '파일 $current / $total';
  }

  @override
  String exportProgressRemaining(int minutes, int seconds) {
    return '$minutes분 $seconds초 남음';
  }

  @override
  String get exportProgressCancelButton => '취소';

  @override
  String get exportProgressOpenVideoButton => '비디오 열기';

  @override
  String get exportVideoListFallbackTitle => '생성된 비디오';

  @override
  String get exportVideoListHeaderTitle => '내보낸 비디오';

  @override
  String get exportVideoListEmptyTitle => '아직 내보낸 비디오가 없습니다';

  @override
  String get exportVideoListEmptySubtitle => '내보낸 비디오가 여기에 표시됩니다';

  @override
  String get exportVideoListFileNotFoundTitle => '파일을 찾을 수 없음';

  @override
  String get exportVideoListFileNotFoundMessage => '이 비디오 파일은 기기에서 삭제되었습니다.';

  @override
  String get exportVideoListDeleteDialogTitle => '비디오를 삭제하시겠습니까?';

  @override
  String get exportVideoListDeleteDialogMessage => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get exportVideoListViewGeneratedTooltip => '생성된 비디오 보기';

  @override
  String exportVideoListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 비디오',
      one: '1개 비디오',
      zero: '0개 비디오',
    );
    return '$_temp0';
  }

  @override
  String get audioMixerTitle => '오디오 믹서';

  @override
  String get audioMixerAudioOnlyPlay => '오디오만 재생';

  @override
  String get audioMixerUseOriginalVideoAudio => '원본 비디오 오디오 사용';

  @override
  String get audioMixerNoAudioLayers => '오디오 레이어를 찾을 수 없음';

  @override
  String get audioMixerMuted => '음소거됨';

  @override
  String get audioMixerVolumeSuffix => '볼륨';

  @override
  String get audioReactivePresetsTitle => '프리셋';

  @override
  String get audioReactivePresetUltraSubtle => '초미세';

  @override
  String get audioReactivePresetSubtle => '미세';

  @override
  String get audioReactivePresetSoft => '부드러움';

  @override
  String get audioReactivePresetNormal => '보통';

  @override
  String get audioReactivePresetGroove => '그루브';

  @override
  String get audioReactivePresetPunchy => '펀치감 있는';

  @override
  String get audioReactivePresetHard => '강하게';

  @override
  String get audioReactivePresetExtreme => '극한';

  @override
  String get audioReactivePresetInsane => '미친 듯이';

  @override
  String get audioReactivePresetChill => '차분하게';

  @override
  String get audioReactiveSidebarTooltip => '오디오 반응형';

  @override
  String get audioReactiveTargetOverlayLabel => '타겟 오버레이';

  @override
  String get audioReactiveNoOverlays => '사용 가능한 오버레이 없음';

  @override
  String get audioReactiveOverlayTypeMedia => '미디어';

  @override
  String get audioReactiveOverlayTypeAudioReactive => '오디오 반응형';

  @override
  String get audioReactiveOverlayTypeText => '텍스트';

  @override
  String get audioReactiveOverlayTypeVisualizer => '비주얼라이저';

  @override
  String get audioReactiveOverlayTypeShader => '셰이더';

  @override
  String get audioReactiveOverlayTypeUnknown => '알 수 없음';

  @override
  String get audioReactiveOverlayUnnamed => '이름 없음';

  @override
  String get audioReactiveAudioSourceLabel => '오디오 소스';

  @override
  String get audioReactiveAudioSourceMixed => '모든 오디오 (믹스됨)';

  @override
  String get audioReactiveAudioSourceUnnamed => '이름 없는 오디오';

  @override
  String get audioReactiveNoDedicatedTracks =>
      '전용 오디오 트랙을 찾을 수 없습니다. 글로벌 믹스를 사용합니다.';

  @override
  String get audioReactiveReactiveTypeLabel => '반응 유형:';

  @override
  String get audioReactiveReactiveTypeScale => '크기 (확대/축소)';

  @override
  String get audioReactiveReactiveTypeRotation => '회전';

  @override
  String get audioReactiveReactiveTypeOpacity => '투명도';

  @override
  String get audioReactiveReactiveTypePosX => '위치 X (수평)';

  @override
  String get audioReactiveReactiveTypePosY => '위치 Y (수직)';

  @override
  String get audioReactiveReactiveTypeFallback => '크기';

  @override
  String get audioReactiveSensitivityLabel => '감도';

  @override
  String get audioReactiveFrequencyRangeLabel => '주파수 범위';

  @override
  String get audioReactiveFrequencyAll => '전체';

  @override
  String get audioReactiveFrequencyBass => '저음 (BASS)';

  @override
  String get audioReactiveFrequencyMid => '중음 (MID)';

  @override
  String get audioReactiveFrequencyTreble => '고음 (TREBLE)';

  @override
  String get audioReactiveSmoothingLabel => '스무딩';

  @override
  String get audioReactiveDelayLabel => '지연 (Delay)';

  @override
  String get audioReactiveMinLabel => '최소';

  @override
  String get audioReactiveMaxLabel => '최대';

  @override
  String get audioReactiveInvertLabel => '반응 반전';

  @override
  String get audioReactiveOn => 'ON';

  @override
  String get audioReactiveOff => 'OFF';

  @override
  String get editorFadeTitle => '페이드 인 / 아웃';

  @override
  String get editorVolumeTitle => '에셋 볼륨';

  @override
  String get editorVolumeMute => '음소거';

  @override
  String get editorVolumeReset => '초기화';

  @override
  String get editorActionVideo => '비디오';

  @override
  String get editorActionImage => '이미지';

  @override
  String get editorActionAudio => '오디오';

  @override
  String get editorActionText => '텍스트';

  @override
  String get editorActionVisualizer => '비주얼라이저';

  @override
  String get editorActionShader => '셰이더';

  @override
  String get editorActionMedia => '미디어';

  @override
  String get editorActionReactive => '반응형';

  @override
  String get editorActionDelete => '삭제';

  @override
  String get editorActionSplit => '분할';

  @override
  String get editorActionClone => '복제';

  @override
  String get editorActionSettings => '설정';

  @override
  String get editorActionVolume => '볼륨';

  @override
  String get editorActionFade => '페이드';

  @override
  String get editorActionSpeed => '속도';

  @override
  String get editorActionReplace => '교체';

  @override
  String get editorActionEdit => '편집';

  @override
  String get colorEditorSelect => '선택';

  @override
  String get mediaPermissionRequired => '미디어 권한이 필요합니다!';

  @override
  String get archiveHeaderTitle => '아카이브 관리자';

  @override
  String get archiveExportSectionTitle => '프로젝트 내보내기 (.vvz)';

  @override
  String get archiveTargetFolderLabel => '대상 폴더';

  @override
  String get archiveTargetFolderResolving => '기본값 확인 중...';

  @override
  String get archiveTargetFolderDefault => '다운로드 (자동)';

  @override
  String get archiveChooseFolder => '선택';

  @override
  String get archiveResetFolder => '초기화';

  @override
  String get archiveIosFolderUnsupported =>
      'iOS에서는 폴더 선택이 지원되지 않습니다. 기본값을 사용합니다.';

  @override
  String get archiveStatsTotalLabel => '합계';

  @override
  String get archiveStatsVideosLabel => '비디오';

  @override
  String get archiveStatsAudiosLabel => '오디오';

  @override
  String get archiveStatsImagesLabel => '이미지';

  @override
  String get archiveStatsMissingLabel => '누락됨';

  @override
  String get archiveIncludeVideos => '비디오 포함';

  @override
  String get archiveIncludeAudios => '오디오 포함';

  @override
  String get archiveMaxVideoSizeLabel => '최대 비디오 크기 (MB)';

  @override
  String get archiveMaxTotalSizeLabel => '최대 합계 크기 (MB)';

  @override
  String get archiveUnlimited => '무제한';

  @override
  String get archiveUnlimitedHint => '0 = 무제한';

  @override
  String get archiveEstimating => '계산 중...';

  @override
  String get archiveSizeEstimateNone => '예상 크기: -';

  @override
  String archiveSizeEstimate(int files, double sizeMb, int skipped) {
    return '파일: $files, 크기: $sizeMb MB, 건너뜀: $skipped';
  }

  @override
  String get archiveSizeWarning => '경고: 예상 크기가 최대 합계를 초과합니다. 내보내기가 차단됩니다.';

  @override
  String get archiveNoMedia => '내보낼 미디어가 없습니다. 미디어를 추가하거나 누락된 파일을 다시 연결하세요.';

  @override
  String get archiveExportButton => '내보내기';

  @override
  String get archiveImportButton => '가져오기';

  @override
  String get archiveRelinkButton => '다시 연결';

  @override
  String archiveExportedSnack(String path) {
    return '내보내기 완료: $path';
  }

  @override
  String get archiveImportProjectDialogTitle => '프로젝트 가져오기';

  @override
  String get archiveImportProjectDialogMessage =>
      '현재 프로젝트에 미디어가 있습니다. 어떻게 진행하시겠습니까?';

  @override
  String get archiveImportProjectCreateNew => '새로 만들기';

  @override
  String get archiveImportProjectReplaceCurrent => '현재 프로젝트 교체';

  @override
  String get archiveImportCancelled => '가져오기 취소됨';

  @override
  String get archiveImportFailed => '가져오기 실패';

  @override
  String get archiveExportPathHint => '내보내기 경로: 앱 문서/exports/<프로젝트><타임스탬프>.vvz';

  @override
  String get archivePreviewLabel => '미리보기';

  @override
  String get archiveProgressPreparing => '파일 준비 중';

  @override
  String get archiveProgressPackaging => '프로젝트 패키징 중';

  @override
  String get archiveProgressCompressing => '압축 중';

  @override
  String get archiveProgressExtracting => '압축 해제 중';

  @override
  String get archiveProgressFinalizing => '마무리 중';

  @override
  String get archiveProgressWorking => '작업 중';

  @override
  String get archiveProgressCompletedTitle => '완료';

  @override
  String get archiveProgressErrorTitle => '오류';

  @override
  String get archiveProgressUnexpectedError => '예기치 않은 오류';

  @override
  String get archiveProgressDone => '완료';

  @override
  String get archiveProgressOpenFile => '파일 열기';

  @override
  String get archiveProgressShare => '공유';

  @override
  String get archiveProgressCancel => '취소';

  @override
  String get archiveProgressHide => '숨기기';

  @override
  String get relinkHeaderTitle => '누락된 미디어 다시 연결';

  @override
  String relinkSuccessSnack(int count) {
    return '$count개 항목이 성공적으로 다시 연결되었습니다';
  }

  @override
  String get relinkNoMatchesSnack =>
      '선택한 폴더에서 일치하는 파일을 찾을 수 없습니다.\n파일 이름이 정확히 일치해야 합니다.';

  @override
  String relinkErrorScanSnack(String error) {
    return '폴더 스캔 오류: $error';
  }

  @override
  String relinkRelinkedSnack(String fileName) {
    return '다시 연결됨: $fileName';
  }

  @override
  String get relinkSaveAndCloseTooltip => '저장 및 닫기';

  @override
  String get relinkNoMissingMedia => '누락되거나 삭제된 미디어를 찾을 수 없습니다.';

  @override
  String get relinkScanFolderButton => '폴더에서 누락된 파일 검색';

  @override
  String get relinkRescanTooltip => '다시 스캔';

  @override
  String get exportShareMessage => '제 비디오를 확인해보세요!';

  @override
  String get exportShareInstagram => 'Instagram';

  @override
  String get exportShareWhatsApp => 'WhatsApp';

  @override
  String get exportShareTikTok => 'TikTok';

  @override
  String get exportShareMore => '더보기';

  @override
  String get exportFullCancelButton => '내보내기 취소';

  @override
  String get exportFullCloseButton => '닫기';

  @override
  String get exportFullDoNotLock => '화면을 잠그거나 다른 앱으로 전환하지 마세요';

  @override
  String get playbackPreviewTitle => '미리보기';

  @override
  String get shaderSubmenuEffectsTooltip => '이펙트';

  @override
  String get shaderSubmenuFiltersTooltip => '필터';

  @override
  String get shaderTypeEffectLabel => '이펙트 유형';

  @override
  String get shaderTypeFilterLabel => '필터 유형';

  @override
  String get shaderEffectTypeRainName => 'Rain';

  @override
  String get shaderEffectTypeRainDesc => 'Animated rain drops';

  @override
  String get shaderEffectTypeRainGlassName => 'Rain Glass';

  @override
  String get shaderEffectTypeRainGlassDesc =>
      'Rain on glass with foggy streaks';

  @override
  String get shaderEffectTypeSnowName => 'Snow';

  @override
  String get shaderEffectTypeSnowDesc => 'Animated snow flakes';

  @override
  String get shaderEffectTypeWaterName => 'Water Ripple';

  @override
  String get shaderEffectTypeWaterDesc => 'Water ripple distortion';

  @override
  String get shaderEffectTypeHalftoneName => 'Halftone';

  @override
  String get shaderEffectTypeHalftoneDesc => 'Halftone dot raster effect';

  @override
  String get shaderEffectTypeTilesName => 'Tiles';

  @override
  String get shaderEffectTypeTilesDesc => 'Tiles/mosaic segmentation effect';

  @override
  String get shaderEffectTypeCircleRadiusName => 'Circle Radius';

  @override
  String get shaderEffectTypeCircleRadiusDesc =>
      'Circle pixelization based on luminance';

  @override
  String get shaderEffectTypeDunesName => 'Dunes';

  @override
  String get shaderEffectTypeDunesDesc => 'Dunes-like quantization look';

  @override
  String get shaderEffectTypeHeatVisionName => 'Heat Vision';

  @override
  String get shaderEffectTypeHeatVisionDesc => 'Heat map style color mapping';

  @override
  String get shaderEffectTypeSpectrumName => 'Spectrum Shift';

  @override
  String get shaderEffectTypeSpectrumDesc => 'RGB spectrum shift/aberration';

  @override
  String get shaderEffectTypeWaveWaterName => 'Wave Water';

  @override
  String get shaderEffectTypeWaveWaterDesc => 'Simple water wave refraction';

  @override
  String get shaderEffectTypeWater2dName => 'Water 2D';

  @override
  String get shaderEffectTypeWater2dDesc => 'Fast 2D water lens distortion';

  @override
  String get shaderEffectTypeSphereName => 'Sphere';

  @override
  String get shaderEffectTypeSphereDesc => 'Spinning sphere overlay simulation';

  @override
  String get shaderEffectTypeFisheName => 'Fisheye FX';

  @override
  String get shaderEffectTypeFisheDesc =>
      'Fisheye distortion with chromatic aberration';

  @override
  String get shaderEffectTypeHdBoostName => 'HD Boost';

  @override
  String get shaderEffectTypeHdBoostDesc =>
      'Boosts sharpness and micro-contrast';

  @override
  String get shaderEffectTypeSharpenName => 'Sharpen';

  @override
  String get shaderEffectTypeSharpenDesc =>
      'Basic sharpening (unsharp mask variant)';

  @override
  String get shaderEffectTypeEdgeDetectName => 'Edge Detect';

  @override
  String get shaderEffectTypeEdgeDetectDesc => 'Sobel-based edge detection';

  @override
  String get shaderEffectTypePixelateName => 'Pixelate';

  @override
  String get shaderEffectTypePixelateDesc =>
      'Large pixel blocks posterized look';

  @override
  String get shaderEffectTypePosterizeName => 'Posterize';

  @override
  String get shaderEffectTypePosterizeDesc =>
      'Reduces color levels (posterize)';

  @override
  String get shaderEffectTypeChromAberrationName => 'Chromatic Aberration';

  @override
  String get shaderEffectTypeChromAberrationDesc =>
      'Offsets color channels outward (lens CA)';

  @override
  String get shaderEffectTypeCrtName => 'CRT Display';

  @override
  String get shaderEffectTypeCrtDesc =>
      'Old CRT display (scanlines + barrel distortion)';

  @override
  String get shaderEffectTypeSwirlName => 'Swirl';

  @override
  String get shaderEffectTypeSwirlDesc => 'Swirl distortion around center';

  @override
  String get shaderEffectTypeFisheyeName => 'Fisheye';

  @override
  String get shaderEffectTypeFisheyeDesc => 'Fisheye (barrel) distortion';

  @override
  String get shaderEffectTypeZoomBlurName => 'Zoom Blur';

  @override
  String get shaderEffectTypeZoomBlurDesc => 'Radial zoom blur towards center';

  @override
  String get shaderEffectTypeFilmGrainName => 'Film Grain';

  @override
  String get shaderEffectTypeFilmGrainDesc => 'Subtle animated film grain';

  @override
  String get shaderEffectTypeBlurName => 'Blur';

  @override
  String get shaderEffectTypeBlurDesc => 'Gaussian blur';

  @override
  String get shaderEffectTypeVignetteName => 'Vignette';

  @override
  String get shaderEffectTypeVignetteDesc => 'Cinematic vignette';

  @override
  String get mediaPickerFiles => 'Files';

  @override
  String mediaPickerAlbumCount(String albumName, int count) {
    return '$albumName • $count Media';
  }

  @override
  String mediaPickerSelectedCount(int count) {
    return '$count Selected';
  }

  @override
  String get mediaPermissionDeniedTitle => 'Cannot Access Gallery';

  @override
  String get mediaPermissionDeniedMessage =>
      'We need permission to access your photos and videos.';

  @override
  String get mediaPermissionManageButton => 'Manage Permissions';

  @override
  String get mediaPermissionNotNow => 'Not Now';

  @override
  String get mediaPickerAudioFallbackTitle => 'Audio';

  @override
  String get shaderParamIntensityShort => '강도';

  @override
  String get shaderParamSpeedShort => '속도';

  @override
  String get shaderParamSizeShort => '크기';

  @override
  String get shaderParamDensityShort => '밀도';

  @override
  String get shaderParamAngleShort => '각도';

  @override
  String get shaderParamFrequencyShort => '주파수';

  @override
  String get shaderParamAmplitudeShort => '진폭';

  @override
  String get shaderParamBlurShort => '블러';

  @override
  String get shaderParamVignetteShort => '비네트';

  @override
  String get shaderParamIntensity => '강도 (세기)';

  @override
  String get shaderParamSpeed => '속도 (빠르기)';

  @override
  String get shaderParamSize => '크기 (비율)';

  @override
  String get shaderParamDensity => '밀도 (양)';

  @override
  String get shaderParamAngle => '각도 (방향)';

  @override
  String get shaderParamFrequency => '주파수 (상세)';

  @override
  String get shaderParamAmplitude => '진폭 (세기)';

  @override
  String get shaderParamBlurRadius => '블러 반경 (양)';

  @override
  String get shaderParamVignetteSize => '비네트 크기';

  @override
  String get shaderParamColor => '색상';

  @override
  String get shaderParamFractalSize => '복잡도 (상세 레벨)';

  @override
  String get shaderParamFractalDensity => '스케일 (줌)';

  @override
  String get shaderParamPsychedelicSize => '스케일 (줌)';

  @override
  String get shaderParamPsychedelicDensity => '복잡도 (상세 레벨)';

  @override
  String get textStyleSizeLabel => '크기';

  @override
  String get textStyleAlphaLabel => '알파';

  @override
  String get textStyleTextColor => '텍스트';

  @override
  String get textStyleBoxColor => '박스';

  @override
  String get textStyleOutlineSection => '외곽선';

  @override
  String get textStyleOutlineWidth => '두께';

  @override
  String get textStyleOutlineColor => '색상';

  @override
  String get textStyleShadowGlowSection => '그림자 및 네온';

  @override
  String get textStyleShadowBlur => '블러';

  @override
  String get textStyleShadowOffsetX => '오프셋 X';

  @override
  String get textStyleShadowOffsetY => '오프셋 Y';

  @override
  String get textStyleGlowRadius => '네온 반경';

  @override
  String get textStyleShadowColor => '그림자';

  @override
  String get textStyleGlowColor => '네온';

  @override
  String get textStyleBoxBackgroundSection => '박스 배경';

  @override
  String get textStyleBoxBorderWidth => '테두리';

  @override
  String get textStyleBoxCornerRadius => '반경';

  @override
  String get textStylePreviewLabel => '미리보기';

  @override
  String get textStyleSubmenuStyleTooltip => '스타일';

  @override
  String get textStyleSubmenuEffectsTooltip => '이펙트';

  @override
  String get textStyleSubmenuAnimationTooltip => '애니메이션';

  @override
  String get textStyleFontLabel => '폰트:';

  @override
  String get textStyleEnableBoxLabel => '박스 활성화:';

  @override
  String get textEffectHeader => '이펙트:';

  @override
  String get textEffectPresetHeader => '프리셋:';

  @override
  String get textEffectStrengthLabel => '강도';

  @override
  String get textEffectSpeedLabel => '속도';

  @override
  String get textEffectAngleLabel => '각도';

  @override
  String get textEffectThicknessLabel => '두께';

  @override
  String get textEffectPresetNeon => '네온';

  @override
  String get textEffectPresetRainbow => '무지개';

  @override
  String get textEffectPresetMetal => '메탈';

  @override
  String get textEffectPresetWave => '웨이브';

  @override
  String get textEffectPresetGlitch => '글리치';

  @override
  String get textEffectNameGradient => '그라디언트';

  @override
  String get textEffectNameWave => '웨이브';

  @override
  String get textEffectNameGlitch => '글리치';

  @override
  String get textEffectNameNeon => '네온';

  @override
  String get textEffectNameMetal => '메탈';

  @override
  String get textEffectNameRainbow => '무지개';

  @override
  String get textEffectNameChrome => '크롬';

  @override
  String get textEffectNameScanlines => '스캔라인';

  @override
  String get textEffectNameRgbShift => 'RGB 시프트';

  @override
  String get textEffectNameDuotone => '듀오톤';

  @override
  String get textEffectNameHolo => '홀로그램';

  @override
  String get textEffectNameNoiseFlow => '노이즈 플로우';

  @override
  String get textEffectNameSparkle => '스파클';

  @override
  String get textEffectNameLiquid => '리퀴드';

  @override
  String get textEffectNameInnerGlow => '이너 글로우';

  @override
  String get textEffectNameInnerShadow => '이너 섀도우';

  @override
  String get textEffectNameNone => '없음';

  @override
  String get textAnimHeader => '애니메이션:';

  @override
  String get textAnimSpeedLabel => '속도';

  @override
  String get textAnimAmplitudeLabel => '진폭';

  @override
  String get textAnimPhaseLabel => '위상';

  @override
  String get textAnimNameTypeDelete => '타이핑/삭제';

  @override
  String get textAnimNameSlideLr => '슬라이드 좌-우';

  @override
  String get textAnimNameSlideRl => '슬라이드 우-좌';

  @override
  String get textAnimNameShakeH => '흔들기 (수평)';

  @override
  String get textAnimNameShakeV => '흔들기 (수직)';

  @override
  String get textAnimNameScanRl => '스캔 우-좌';

  @override
  String get textAnimNameSweepLrRl => '스윕 좌우';

  @override
  String get textAnimNameGlowPulse => '글로우 펄스';

  @override
  String get textAnimNameOutlinePulse => '아웃라인 펄스';

  @override
  String get textAnimNameShadowSwing => '그림자 스윙';

  @override
  String get textAnimNameFadeIn => '페이드 인';

  @override
  String get textAnimNameZoomIn => '줌 인';

  @override
  String get textAnimNameSlideUp => '슬라이드 업';

  @override
  String get textAnimNameBlurIn => '블러 인';

  @override
  String get textAnimNameScramble => '스크램블';

  @override
  String get textAnimNameFlipX => '뒤집기 X';

  @override
  String get textAnimNameFlipY => '뒤집기 Y';

  @override
  String get textAnimNamePopIn => '팝 인';

  @override
  String get textAnimNameRubberBand => '고무줄';

  @override
  String get textAnimNameWobble => '워블';

  @override
  String get textPlayerHintEdit => '텍스트를 편집하려면 클릭하세요';

  @override
  String get videoSettingsAspectRatioLabel => '화면 비율:';

  @override
  String get videoSettingsCropModeLabel => '자르기 모드:';

  @override
  String get videoSettingsRotationLabel => '회전:';

  @override
  String get videoSettingsFlipLabel => '뒤집기:';

  @override
  String get videoSettingsBackgroundLabel => '배경:';

  @override
  String get videoSettingsCropModeFit => '맞춤 (Fit)';

  @override
  String get videoSettingsCropModeFill => '채우기 (Fill)';

  @override
  String get videoSettingsCropModeStretch => '늘리기 (Stretch)';

  @override
  String get videoSettingsBackgroundBlack => '검정';

  @override
  String get videoSettingsBackgroundWhite => '흰색';

  @override
  String get videoSettingsBackgroundGray => '회색';

  @override
  String get videoSettingsBackgroundBlue => '파랑';

  @override
  String get videoSettingsBackgroundGreen => '초록';

  @override
  String get videoSettingsBackgroundRed => '빨강';

  @override
  String get videoSpeedTitle => '재생 속도';

  @override
  String get videoSpeedRippleLabel => '리플 (후속 클립 이동)';

  @override
  String get videoSpeedNote =>
      '참고: 미리보기는 플레이어 속도로 오디오를 재생합니다. 내보내기는 FFmpeg atempo를 사용하여 속도를 일치시킵니다.';

  @override
  String get videoSettingsFlipHorizontal => '수평';

  @override
  String get videoSettingsFlipVertical => '수직';

  @override
  String get visualizerSubmenuCanvasTooltip => '캔버스 이펙트';

  @override
  String get visualizerSubmenuProgressTooltip => '진행률 표시줄';

  @override
  String get visualizerSubmenuShaderTooltip => '셰이더 이펙트';

  @override
  String get visualizerSubmenuVisualTooltip => '비주얼 배경';

  @override
  String get visualizerSubmenuSettingsTooltip => '모든 설정';

  @override
  String get visualizerAudioEmptyTimeline => '타임라인에 오디오 소스가 없습니다';

  @override
  String get visualizerAudioLabel => '오디오:';

  @override
  String get visualizerAudioSelectHint => '오디오 선택';

  @override
  String get visualizerEffectLabel => '이펙트:';

  @override
  String get visualizerScaleLabel => '크기:';

  @override
  String get visualizerBarsLabel => '바:';

  @override
  String get visualizerSpacingLabel => '간격:';

  @override
  String get visualizerHeightLabel => '높이:';

  @override
  String get visualizerRotationLabel => '회전:';

  @override
  String get visualizerThicknessLabel => '두께:';

  @override
  String get visualizerGlowLabel => '네온:';

  @override
  String get visualizerMirrorLabel => '거울:';

  @override
  String get visualizerColorLabel => '색상';

  @override
  String get textColorLabel => '색상';

  @override
  String get visualizerGradientLabel => '그라디언트:';

  @override
  String get visualizerBackgroundLabel => '배경:';

  @override
  String get visualizerIntensityLabel => '강도:';

  @override
  String get visualizerSpeedLabel => '속도:';

  @override
  String get visualizerVisualLabel => '비주얼:';

  @override
  String get visualizerTrackOpacityLabel => '트랙 투명도:';

  @override
  String get visualizerLabelSizeLabel => '라벨 크기:';

  @override
  String get visualizerLabelAnimLabel => '라벨 애니메이션:';

  @override
  String get visualizerLabelPositionLabel => '라벨 위치:';

  @override
  String get visualizerStyleLabel => '스타일:';

  @override
  String get visualizerCornerLabel => '모서리:';

  @override
  String get visualizerGapLabel => '간격:';

  @override
  String get visualizerHeadSizeLabel => '헤드 크기:';

  @override
  String get visualizerHeadAnimLabel => '헤드 애니메이션:';

  @override
  String get visualizerHeadEffectLabel => '헤드 이펙트:';

  @override
  String get visualizerPresetsLabel => '프리셋:';

  @override
  String get visualizerTrackLabel => '트랙:';

  @override
  String get visualizerVisualFullscreenTooltip => '비주얼라이저를 전체 화면 오버레이로 그리기';

  @override
  String get visualizerShaderFullscreenTooltip => '비주얼라이저 셰이더를 전체 화면 배경으로 그리기';

  @override
  String get visualizerShaderLabel => '셰이더:';

  @override
  String get visualizerShaderOptionBars => '바 (Bars)';

  @override
  String get visualizerShaderOptionCircleBars => '원형 바';

  @override
  String get visualizerShaderOptionCircle => '원';

  @override
  String get visualizerShaderOptionNationCircle => '네이션 서클';

  @override
  String get visualizerShaderOptionWaveform => '파형';

  @override
  String get visualizerShaderOptionSmoothCurves => '부드러운 곡선';

  @override
  String get visualizerShaderOptionClaudeSpectrum => 'Claude 스펙트럼';

  @override
  String get visualizerShaderOptionSinusWaves => '사인파';

  @override
  String get visualizerShaderOptionOrb => '구체 (Orb)';

  @override
  String get visualizerShaderOptionPyramid => '피라미드';

  @override
  String get visualizerThemeLabel => '테마:';

  @override
  String get visualizerProgressStyleCapsule => '캡슐';

  @override
  String get visualizerProgressStyleSegments => '세그먼트';

  @override
  String get visualizerProgressStyleSteps => '단계';

  @override
  String get visualizerProgressStyleCentered => '중앙 정렬';

  @override
  String get visualizerProgressStyleOutline => '외곽선';

  @override
  String get visualizerProgressStyleThin => '얇게';

  @override
  String get visualizerHeadAnimNone => '없음';

  @override
  String get visualizerHeadAnimStatic => '정지';

  @override
  String get visualizerHeadAnimPulse => '펄스';

  @override
  String get visualizerHeadAnimSpark => '스파크';

  @override
  String get visualizerPresetClean => '깔끔함';

  @override
  String get visualizerPresetNeonClub => '네온 클럽';

  @override
  String get visualizerPresetCinematic => '시네마틱';

  @override
  String get visualizerPresetGlitchy => '글리치';

  @override
  String get visualizerPresetFireBlast => '파이어 블래스트';

  @override
  String get visualizerPresetElectricBlue => '일렉트릭 블루';

  @override
  String get visualizerPresetRainbowRoad => '레인보우 로드';

  @override
  String get visualizerPresetSoftPastel => '소프트 파스텔';

  @override
  String get visualizerPresetIceCold => '아이스 콜드';

  @override
  String get visualizerPresetMatrixCode => '매트릭스 코드';

  @override
  String get visualizerThemeClassic => '클래식';

  @override
  String get visualizerThemeFire => '불';

  @override
  String get visualizerThemeElectric => '일렉트릭';

  @override
  String get visualizerThemeNeon => '네온';

  @override
  String get visualizerThemeRainbow => '무지개';

  @override
  String get visualizerThemeGlitch => '글리치';

  @override
  String get visualizerThemeSoft => '소프트';

  @override
  String get visualizerThemeSunset => '일몰';

  @override
  String get visualizerThemeIce => '얼음';

  @override
  String get visualizerThemeMatrix => '매트릭스';

  @override
  String get visualizerLabelSizeSmall => '작게';

  @override
  String get visualizerLabelSizeNormal => '보통';

  @override
  String get visualizerLabelSizeLarge => '크게';

  @override
  String get visualizerCounterAnimStatic => '정지';

  @override
  String get visualizerCounterAnimPulse => '펄스';

  @override
  String get visualizerCounterAnimFlip => '뒤집기';

  @override
  String get visualizerCounterAnimLeaf => '나뭇잎';

  @override
  String get visualizerCounterPositionCenter => '중앙';

  @override
  String get visualizerCounterPositionTop => '상단';

  @override
  String get visualizerCounterPositionBottom => '하단';

  @override
  String get visualizerCounterPositionSides => '측면';

  @override
  String get visualizerOverlaySettingsTitle => '오버레이 설정:';

  @override
  String get visualizerOverlayCenterImageLabel => '중앙 이미지';

  @override
  String get visualizerOverlayRingColorLabel => '링 색상';

  @override
  String get visualizerOverlayBackgroundLabel => '배경';

  @override
  String get visualizerNoAudioSource => '오디오 소스 없음';

  @override
  String get mediaOverlaySubmenuTooltip => '미디어 오버레이';

  @override
  String get mediaOverlayAnimDurationLabel => '애니메이션 시간';

  @override
  String mediaOverlaySourceTitle(int count) {
    return '소스 ($count개 사용 가능)';
  }

  @override
  String get mediaOverlayAddVideo => '비디오 추가';

  @override
  String get mediaOverlayAddImage => '이미지 추가';

  @override
  String mediaOverlayPositionLabel(String axis) {
    return '위치 $axis';
  }

  @override
  String get mediaOverlayScaleLabel => '크기';

  @override
  String get mediaOverlayOpacityLabel => '투명도';

  @override
  String get mediaOverlayRotationLabel => '회전';

  @override
  String get mediaOverlayCornerLabel => '모서리';

  @override
  String get mediaOverlayAnimationLabel => '애니메이션:';

  @override
  String get mediaOverlayAnimNone => '없음';

  @override
  String get mediaOverlayAnimFadeIn => '페이드 인';

  @override
  String get mediaOverlayAnimFadeOut => '페이드 아웃';

  @override
  String get mediaOverlayAnimSlideLeft => '슬라이드 ←';

  @override
  String get mediaOverlayAnimSlideRight => '슬라이드 →';

  @override
  String get mediaOverlayAnimSlideUp => '슬라이드 ↑';

  @override
  String get mediaOverlayAnimSlideDown => '슬라이드 ↓';

  @override
  String get mediaOverlayAnimZoomIn => '줌 인';

  @override
  String get mediaOverlayAnimZoomOut => '줌 아웃';

  @override
  String get mediaPickerTitle => '📱 기기에서 미디어 선택';

  @override
  String mediaPickerLoadedCount(int count) {
    return '$count개 항목 로드됨';
  }

  @override
  String get mediaPickerSearchHint => '미디어 검색...';

  @override
  String mediaPickerTabAll(int count) {
    return '전체 ($count)';
  }

  @override
  String mediaPickerTabImages(int count) {
    return '이미지 ($count)';
  }

  @override
  String mediaPickerTabVideos(int count) {
    return '비디오 ($count)';
  }

  @override
  String mediaPickerTabAudio(int count) {
    return '오디오 ($count)';
  }

  @override
  String get mediaPickerSelectionLabel => '개 미디어 선택됨';

  @override
  String get mediaPickerClearSelection => '해제';

  @override
  String get mediaPickerLoading => '미디어 로드 중...';

  @override
  String get mediaPickerEmpty => '미디어를 찾을 수 없음';

  @override
  String get mediaPickerTypeVideo => '비디오';

  @override
  String get mediaPickerTypeImage => '이미지';

  @override
  String get mediaPickerTypeAudio => '오디오';

  @override
  String mediaPickerAddToProject(int count) {
    return '프로젝트에 추가 ($count)';
  }

  @override
  String mediaPickerErrorGeneric(String error) {
    return '오류: $error';
  }

  @override
  String get visualizerSettingsAdvancedTitle => '고급 설정';

  @override
  String get visualizerSettingsAdvancedSubtitle => 'FFT 및 오디오 처리 매개변수';

  @override
  String get visualizerSettingsApplyFftSnack => '새 매개변수로 FFT 재계산 중...';

  @override
  String get visualizerSettingsApplyFftButton => '적용 및 FFT 재계산';

  @override
  String get visualizerSettingsStaticTitle => '정적 매개변수';

  @override
  String get visualizerSettingsStaticFftSizeLabel => 'FFT 크기';

  @override
  String get visualizerSettingsStaticFftSizeValue => '2048';

  @override
  String get visualizerSettingsStaticFftSizeTooltip => 'FFT 계산을 위한 윈도우 크기 (고정)';

  @override
  String get visualizerSettingsStaticHopSizeLabel => '홉(Hop) 크기';

  @override
  String get visualizerSettingsStaticHopSizeValue => '512';

  @override
  String get visualizerSettingsStaticHopSizeTooltip => 'FFT 윈도우 간의 단계 크기 (고정)';

  @override
  String get visualizerSettingsStaticSampleRateLabel => '샘플링 레이트';

  @override
  String get visualizerSettingsStaticSampleRateValue => '44.1 kHz';

  @override
  String get visualizerSettingsStaticSampleRateTooltip => '오디오 샘플링 속도 (고정)';

  @override
  String get visualizerSettingsCacheTitle => '캐시 상태';

  @override
  String get visualizerSettingsClearCacheSnack => 'FFT 캐시가 삭제되었습니다';

  @override
  String get visualizerSettingsClearCacheButton => 'FFT 캐시 삭제';

  @override
  String get visualizerSettingsPerformanceTitle => '성능';

  @override
  String get visualizerSettingsRenderPipelineLabel => '렌더 파이프라인';

  @override
  String get visualizerSettingsRenderPipelineCanvas => '캔버스 (CPU)';

  @override
  String get visualizerSettingsRenderPipelineShader => '셰이더 (GPU)';

  @override
  String get visualizerSettingsRenderPipelineTooltip => '현재 렌더링 백엔드';

  @override
  String get visualizerSettingsFftAboutTitle => 'ℹ️ FFT 처리에 대하여';

  @override
  String get visualizerSettingsFftAboutBody =>
      '오디오는 2048 포인트 FFT로 처리되며, 64개의 로그 스케일 대역(50Hz-16kHz)으로 다운샘플링되고, 프레임별로 정규화되며, 안정적인 시각화를 위해 EMA(α=0.6)로 평활화됩니다.';

  @override
  String get visualizerSettingsPresetsTitle => '프리셋';

  @override
  String get visualizerSettingsPresetsTooltip =>
      'FFT 대역, 스무딩 및 다이내믹스를 위한 빠른 프로필.';

  @override
  String get visualizerSettingsPresetCinematic => '시네마틱';

  @override
  String get visualizerSettingsPresetAggressive => '공격적';

  @override
  String get visualizerSettingsPresetLofi => '로파이 (Lo-Fi)';

  @override
  String get visualizerSettingsPresetBassHeavy => '저음 강조';

  @override
  String get visualizerSettingsPresetVocalFocus => '보컬 집중';

  @override
  String visualizerSettingsPresetAppliedSnack(Object preset) {
    return '\"$preset\" 프리셋이 적용되었습니다. 전체 효과를 보려면 \"적용 및 FFT 재계산\"을 누르세요.';
  }

  @override
  String get visualizerSettingsReactivityLabel => '반응성';

  @override
  String get visualizerSettingsReactivityTooltip =>
      '곡선 형성 (0.5-2.0). 높음 = 더 공격적인 반응, 낮음 = 더 부드러움.';

  @override
  String get visualizerSettingsCacheCachedTitle => 'FFT 데이터 캐시됨';

  @override
  String get visualizerSettingsCacheProcessingTitle => 'FFT 처리 중...';

  @override
  String get visualizerSettingsCacheCachedSubtitle => '오디오 분석 완료 및 준비됨';

  @override
  String get visualizerSettingsCacheProcessingSubtitle =>
      '백그라운드에서 오디오를 분석 중입니다';

  @override
  String get visualizerSettingsFftBandsLabel => 'FFT 대역';

  @override
  String get visualizerSettingsFftBandsTooltip =>
      '주파수 대역 수 (32/64/128). 대역이 많을수록 더 세밀하지만 처리가 느려집니다.';

  @override
  String visualizerSettingsFftBandsValue(int bands) {
    return '$bands 밴드';
  }

  @override
  String get visualizerSettingsSmoothingLabel => '스무딩 (EMA α)';

  @override
  String get visualizerSettingsSmoothingTooltip =>
      '시간적 평활화 계수 (0.0-1.0). 높음 = 더 빠른 반응, 낮음 = 부드럽지만 지연됨.';

  @override
  String get visualizerSettingsFrequencyRangeLabel => '주파수 범위';

  @override
  String get visualizerSettingsFrequencyRangeTooltip =>
      'Hz 단위의 분석된 주파수 범위. 저음이 많은 콘텐츠(최솟값 낮춤) 또는 고음 중심 콘텐츠(최솟값 높임)에 맞춰 조정하세요.';

  @override
  String visualizerSettingsFrequencyMinLabel(int hz) {
    return '최소: $hz Hz';
  }

  @override
  String visualizerSettingsFrequencyMaxLabel(int hz) {
    return '최대: $hz Hz';
  }

  @override
  String get visualizerSettingsAnimSmoothnessLabel => '애니메이션 부드러움';

  @override
  String get visualizerSettingsAnimSmoothnessTooltip =>
      '대역 스무딩 (0.0-1.0). 높음 = 깜박임이 줄어들고 대역 간 블러가 증가합니다.';
}
