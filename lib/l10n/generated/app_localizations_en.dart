// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearanceSectionTitle => 'Appearance';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSubtitleSystem => 'System default';

  @override
  String get themeOptionSystem => 'System';

  @override
  String get themeOptionLight => 'Light';

  @override
  String get themeOptionDark => 'Dark';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSubtitle => 'Select application language';

  @override
  String get languageOptionEnglish => 'English';

  @override
  String get languageOptionTurkish => 'Turkish';

  @override
  String get languageOptionSpanish => 'Spanish';

  @override
  String get languageOptionPortuguese => 'Portuguese';

  @override
  String get languageOptionHindi => 'Hindi';

  @override
  String get languageOptionChinese => 'Chinese';

  @override
  String get languageOptionArabic => 'Arabic';

  @override
  String get languageOptionFrench => 'French';

  @override
  String get languageOptionGerman => 'German';

  @override
  String get languageOptionRussian => 'Russian';

  @override
  String get languageOptionJapanese => 'Japanese';

  @override
  String get languageOptionKorean => 'Korean';

  @override
  String get performanceSectionTitle => 'Performance & Cache';

  @override
  String get clearVisualizerCacheTitle => 'Clear visualizer cache';

  @override
  String get clearVisualizerCacheSubtitle => 'Discard precomputed FFT data';

  @override
  String get clearVisualizerCacheSnack => 'Visualizer cache cleared';

  @override
  String get clearAudioReactiveCacheTitle => 'Clear audio reactive cache';

  @override
  String get clearAudioReactiveCacheSubtitle => 'Discard cached FFT data';

  @override
  String get clearAudioReactiveCacheSnack => 'Audio reactive cache cleared';

  @override
  String get advancedSectionTitle => 'Advanced';

  @override
  String get resetSettingsTitle => 'Reset settings to defaults';

  @override
  String get resetSettingsSubtitle => 'Restore global settings';

  @override
  String get resetSettingsSnack => 'Settings reset to defaults';

  @override
  String get projectListTitle => 'My Projects';

  @override
  String get projectListEmpty => 'No projects yet';

  @override
  String get projectListNewProject => 'New Project';

  @override
  String get projectListContinueEditing => 'Continue Editing';

  @override
  String get projectListDefaultHeadline => 'Professional Editor';

  @override
  String get projectMenuDesign => 'Design';

  @override
  String get projectMenuEditInfo => 'Edit Info';

  @override
  String get projectMenuVideos => 'Videos';

  @override
  String get projectMenuDelete => 'Delete';

  @override
  String get projectDeleteDialogTitle => 'Confirm delete';

  @override
  String get projectDeleteDialogMessage =>
      'Do you want to delete this project?';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonOk => 'OK';

  @override
  String get projectEditAppBarNew => 'New Project';

  @override
  String get projectEditAppBarEdit => 'Edit Project';

  @override
  String get projectEditTitleHint => 'Enter project title';

  @override
  String get projectEditTitleValidation => 'Please enter a title';

  @override
  String get projectEditDescriptionHint => 'Add description (optional)';

  @override
  String get projectEditCreateButton => 'Create Project';

  @override
  String get projectEditSaveButton => 'Save Changes';

  @override
  String get directorMissingAssetsTitle => 'Some assets have been deleted';

  @override
  String get directorMissingAssetsMessage =>
      'To continue you must recover deleted assets on your device or remove them from the timeline (marked in red).';

  @override
  String get editorHeaderCloseTooltip => 'Close';

  @override
  String get editorHeaderArchiveTooltip => 'Import/Export Project (.vvz)';

  @override
  String get editorHeaderViewGeneratedTooltip => 'View Generated Videos';

  @override
  String get editorHeaderExportTooltip => 'Export Video';

  @override
  String get editorHeaderAddVideoFirstTooltip => 'Add video first';

  @override
  String get editorGenerateTooltip => 'Generate video';

  @override
  String get editorGenerateFullHdLabel => 'Generate Full HD 1080px';

  @override
  String get editorGenerateHdLabel => 'Generate HD 720px';

  @override
  String get editorGenerateSdLabel => 'Generate SD 360px';

  @override
  String get exportSheetTitle => 'Export Video';

  @override
  String get exportSheetResolutionLabel => 'Resolution';

  @override
  String get exportSheetResolutionHelp =>
      'Higher Resolution: Crystal Clear Playback for large screen';

  @override
  String get exportSheetFileFormatLabel => 'File Format';

  @override
  String get exportSheetFpsLabel => 'Frames Per Second';

  @override
  String get exportSheetFpsHelp => 'Higher frame rate makes smoother animation';

  @override
  String get exportSheetQualityLabel => 'Quality / Bitrate';

  @override
  String get exportSheetQualityLow => 'Low';

  @override
  String get exportSheetQualityMedium => 'Medium';

  @override
  String get exportSheetQualityHigh => 'High';

  @override
  String get exportSheetButtonExport => 'Export Video';

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
  String get videoQualityUltra => 'Ultra Quality';

  @override
  String get videoQualityStandard => 'Standard Quality';

  @override
  String get exportLegacyViewVideos => 'View Videos';

  @override
  String get exportProgressPreprocessingTitle => 'Preprocessing files';

  @override
  String get exportProgressBuildingTitle => 'Building your video';

  @override
  String get exportProgressSavedTitle =>
      'Your video has been saved in the gallery';

  @override
  String get exportProgressErrorTitle => 'Error';

  @override
  String get exportProgressErrorMessage =>
      'An unexpected error occurred. We will work on it. Please try again or upgrade to new versions of the app if the error persists.';

  @override
  String exportProgressFileOfTotal(int current, int total) {
    return 'File $current of $total';
  }

  @override
  String exportProgressRemaining(int minutes, int seconds) {
    return '$minutes min $seconds secs remaining';
  }

  @override
  String get exportProgressCancelButton => 'CANCEL';

  @override
  String get exportProgressOpenVideoButton => 'OPEN VIDEO';

  @override
  String get exportVideoListFallbackTitle => 'Generated Videos';

  @override
  String get exportVideoListHeaderTitle => 'Exported Videos';

  @override
  String get exportVideoListEmptyTitle => 'No exported videos yet';

  @override
  String get exportVideoListEmptySubtitle =>
      'Your exported videos will appear here';

  @override
  String get exportVideoListFileNotFoundTitle => 'File Not Found';

  @override
  String get exportVideoListFileNotFoundMessage =>
      'This video file has been deleted from your device.';

  @override
  String get exportVideoListDeleteDialogTitle => 'Delete Video?';

  @override
  String get exportVideoListDeleteDialogMessage =>
      'This action cannot be undone.';

  @override
  String get exportVideoListViewGeneratedTooltip => 'View generated videos';

  @override
  String exportVideoListCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos',
      one: '1 video',
      zero: '0 videos',
    );
    return '$_temp0';
  }

  @override
  String get audioMixerTitle => 'Audio Mixer';

  @override
  String get audioMixerAudioOnlyPlay => 'Audio-only play';

  @override
  String get audioMixerUseOriginalVideoAudio => 'Use original video audio';

  @override
  String get audioMixerNoAudioLayers => 'No audio layers found';

  @override
  String get audioMixerMuted => 'Muted';

  @override
  String get audioMixerVolumeSuffix => 'Volume';

  @override
  String get audioReactivePresetsTitle => 'Presets';

  @override
  String get audioReactivePresetUltraSubtle => 'Ultra Subtle';

  @override
  String get audioReactivePresetSubtle => 'Subtle';

  @override
  String get audioReactivePresetSoft => 'Soft';

  @override
  String get audioReactivePresetNormal => 'Normal';

  @override
  String get audioReactivePresetGroove => 'Groove';

  @override
  String get audioReactivePresetPunchy => 'Punchy';

  @override
  String get audioReactivePresetHard => 'Hard';

  @override
  String get audioReactivePresetExtreme => 'Extreme';

  @override
  String get audioReactivePresetInsane => 'Insane';

  @override
  String get audioReactivePresetChill => 'Chill';

  @override
  String get audioReactiveSidebarTooltip => 'Audio Reactive';

  @override
  String get audioReactiveTargetOverlayLabel => 'Target Overlay';

  @override
  String get audioReactiveNoOverlays => 'No overlays available';

  @override
  String get audioReactiveOverlayTypeMedia => 'Media';

  @override
  String get audioReactiveOverlayTypeAudioReactive => 'Audio Reactive';

  @override
  String get audioReactiveOverlayTypeText => 'Text';

  @override
  String get audioReactiveOverlayTypeVisualizer => 'Visualizer';

  @override
  String get audioReactiveOverlayTypeShader => 'Shader';

  @override
  String get audioReactiveOverlayTypeUnknown => 'Unknown';

  @override
  String get audioReactiveOverlayUnnamed => 'Unnamed';

  @override
  String get audioReactiveAudioSourceLabel => 'Audio Source';

  @override
  String get audioReactiveAudioSourceMixed => 'All Audio (Mixed)';

  @override
  String get audioReactiveAudioSourceUnnamed => 'Unnamed Audio';

  @override
  String get audioReactiveNoDedicatedTracks =>
      'No dedicated audio tracks found. Using global mix.';

  @override
  String get audioReactiveReactiveTypeLabel => 'Reactive Type:';

  @override
  String get audioReactiveReactiveTypeScale => 'Scale (Grow/Shrink)';

  @override
  String get audioReactiveReactiveTypeRotation => 'Rotation (Rotate)';

  @override
  String get audioReactiveReactiveTypeOpacity => 'Opacity (Transparency)';

  @override
  String get audioReactiveReactiveTypePosX => 'Position X (Horizontal)';

  @override
  String get audioReactiveReactiveTypePosY => 'Position Y (Vertical)';

  @override
  String get audioReactiveReactiveTypeFallback => 'Scale';

  @override
  String get audioReactiveSensitivityLabel => 'Sensitivity';

  @override
  String get audioReactiveFrequencyRangeLabel => 'Frequency Range';

  @override
  String get audioReactiveFrequencyAll => 'ALL';

  @override
  String get audioReactiveFrequencyBass => 'BASS';

  @override
  String get audioReactiveFrequencyMid => 'MID';

  @override
  String get audioReactiveFrequencyTreble => 'TREBLE';

  @override
  String get audioReactiveSmoothingLabel => 'Smoothing';

  @override
  String get audioReactiveDelayLabel => 'Delay';

  @override
  String get audioReactiveMinLabel => 'Min';

  @override
  String get audioReactiveMaxLabel => 'Max';

  @override
  String get audioReactiveInvertLabel => 'Invert Reaction';

  @override
  String get audioReactiveOn => 'ON';

  @override
  String get audioReactiveOff => 'OFF';

  @override
  String get editorFadeTitle => 'Fade In / Out';

  @override
  String get editorVolumeTitle => 'Asset Volume';

  @override
  String get editorVolumeMute => 'Mute';

  @override
  String get editorVolumeReset => 'Reset';

  @override
  String get editorActionVideo => 'Video';

  @override
  String get editorActionImage => 'Image';

  @override
  String get editorActionAudio => 'Audio';

  @override
  String get editorActionText => 'Text';

  @override
  String get editorActionVisualizer => 'Visualizer';

  @override
  String get editorActionShader => 'Shader';

  @override
  String get editorActionMedia => 'Media';

  @override
  String get editorActionReactive => 'Reactive';

  @override
  String get editorActionDelete => 'Delete';

  @override
  String get editorActionSplit => 'Split';

  @override
  String get editorActionClone => 'Clone';

  @override
  String get editorActionSettings => 'Settings';

  @override
  String get editorActionVolume => 'Volume';

  @override
  String get editorActionFade => 'Fade';

  @override
  String get editorActionSpeed => 'Speed';

  @override
  String get editorActionReplace => 'Replace';

  @override
  String get editorActionEdit => 'Edit';

  @override
  String get colorEditorSelect => 'SELECT';

  @override
  String get mediaPermissionRequired => 'Media permission is required!';

  @override
  String get archiveHeaderTitle => 'Archive Manager';

  @override
  String get archiveExportSectionTitle => 'Export Project (.vvz)';

  @override
  String get archiveTargetFolderLabel => 'Target folder';

  @override
  String get archiveTargetFolderResolving => 'Resolving default...';

  @override
  String get archiveTargetFolderDefault => 'Downloads (auto)';

  @override
  String get archiveChooseFolder => 'Choose';

  @override
  String get archiveResetFolder => 'Reset';

  @override
  String get archiveIosFolderUnsupported =>
      'Folder selection is not supported on iOS. Using default.';

  @override
  String get archiveStatsTotalLabel => 'Total';

  @override
  String get archiveStatsVideosLabel => 'Videos';

  @override
  String get archiveStatsAudiosLabel => 'Audios';

  @override
  String get archiveStatsImagesLabel => 'Images';

  @override
  String get archiveStatsMissingLabel => 'Missing';

  @override
  String get archiveIncludeVideos => 'Include videos';

  @override
  String get archiveIncludeAudios => 'Include audios';

  @override
  String get archiveMaxVideoSizeLabel => 'Max video size (MB)';

  @override
  String get archiveMaxTotalSizeLabel => 'Max total size (MB)';

  @override
  String get archiveUnlimited => 'Unlimited';

  @override
  String get archiveUnlimitedHint => '0 = Unlimited';

  @override
  String get archiveEstimating => 'Estimating...';

  @override
  String get archiveSizeEstimateNone => 'Size estimate: -';

  @override
  String archiveSizeEstimate(int files, double sizeMb, int skipped) {
    return 'Files: $files, Size: $sizeMb MB, Skipped: $skipped';
  }

  @override
  String get archiveSizeWarning =>
      'Warning: estimated size exceeds max total. Export will be blocked.';

  @override
  String get archiveNoMedia =>
      'No media to export. Add media or relink missing files.';

  @override
  String get archiveExportButton => 'Export';

  @override
  String get archiveImportButton => 'Import';

  @override
  String get archiveRelinkButton => 'Relink';

  @override
  String archiveExportedSnack(String path) {
    return 'Exported: $path';
  }

  @override
  String get archiveImportProjectDialogTitle => 'Import Project';

  @override
  String get archiveImportProjectDialogMessage =>
      'Current project has media. How do you want to proceed?';

  @override
  String get archiveImportProjectCreateNew => 'Create new';

  @override
  String get archiveImportProjectReplaceCurrent => 'Replace current';

  @override
  String get archiveImportCancelled => 'Import cancelled';

  @override
  String get archiveImportFailed => 'Import failed';

  @override
  String get archiveExportPathHint =>
      'Export path: App Documents/exports/<Project><Timestamp>.vvz';

  @override
  String get archivePreviewLabel => 'Preview';

  @override
  String get archiveProgressPreparing => 'Preparing files';

  @override
  String get archiveProgressPackaging => 'Packaging project';

  @override
  String get archiveProgressCompressing => 'Compressing';

  @override
  String get archiveProgressExtracting => 'Extracting';

  @override
  String get archiveProgressFinalizing => 'Finalizing';

  @override
  String get archiveProgressWorking => 'Working';

  @override
  String get archiveProgressCompletedTitle => 'Completed';

  @override
  String get archiveProgressErrorTitle => 'Error';

  @override
  String get archiveProgressUnexpectedError => 'Unexpected error';

  @override
  String get archiveProgressDone => 'Done';

  @override
  String get archiveProgressOpenFile => 'Open file';

  @override
  String get archiveProgressShare => 'Share';

  @override
  String get archiveProgressCancel => 'Cancel';

  @override
  String get archiveProgressHide => 'Hide';

  @override
  String get relinkHeaderTitle => 'Relink Missing Media';

  @override
  String relinkSuccessSnack(int count) {
    return 'Successfully relinked $count item(s)';
  }

  @override
  String get relinkNoMatchesSnack =>
      'No matching files found in selected folder.\nFile names must match exactly.';

  @override
  String relinkErrorScanSnack(String error) {
    return 'Error scanning folder: $error';
  }

  @override
  String relinkRelinkedSnack(String fileName) {
    return 'Relinked: $fileName';
  }

  @override
  String get relinkSaveAndCloseTooltip => 'Save & Close';

  @override
  String get relinkNoMissingMedia => 'No missing or deleted media found.';

  @override
  String get relinkScanFolderButton => 'Scan folder for missing files';

  @override
  String get relinkRescanTooltip => 'Rescan';

  @override
  String get exportShareMessage => 'Check out my video!';

  @override
  String get exportShareInstagram => 'Instagram';

  @override
  String get exportShareWhatsApp => 'WhatsApp';

  @override
  String get exportShareTikTok => 'TikTok';

  @override
  String get exportShareMore => 'More';

  @override
  String get exportFullCancelButton => 'Cancel Export';

  @override
  String get exportFullCloseButton => 'Close';

  @override
  String get exportFullDoNotLock =>
      'Please do not lock screen or switch to other apps';

  @override
  String get playbackPreviewTitle => 'Preview';

  @override
  String get shaderSubmenuEffectsTooltip => 'Effects';

  @override
  String get shaderSubmenuFiltersTooltip => 'Filters';

  @override
  String get shaderTypeEffectLabel => 'Effect Type';

  @override
  String get shaderTypeFilterLabel => 'Filter Type';

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
  String get shaderParamIntensityShort => 'Intensity';

  @override
  String get shaderParamSpeedShort => 'Speed';

  @override
  String get shaderParamSizeShort => 'Size';

  @override
  String get shaderParamDensityShort => 'Density';

  @override
  String get shaderParamAngleShort => 'Angle';

  @override
  String get shaderParamFrequencyShort => 'Frequency';

  @override
  String get shaderParamAmplitudeShort => 'Amplitude';

  @override
  String get shaderParamBlurShort => 'Blur';

  @override
  String get shaderParamVignetteShort => 'Vignette';

  @override
  String get shaderParamIntensity => 'Intensity (Strength)';

  @override
  String get shaderParamSpeed => 'Speed (Rate)';

  @override
  String get shaderParamSize => 'Size (Scale)';

  @override
  String get shaderParamDensity => 'Density (Amount)';

  @override
  String get shaderParamAngle => 'Angle (Direction)';

  @override
  String get shaderParamFrequency => 'Frequency (Detail)';

  @override
  String get shaderParamAmplitude => 'Amplitude (Strength)';

  @override
  String get shaderParamBlurRadius => 'Blur Radius (Amount)';

  @override
  String get shaderParamVignetteSize => 'Vignette Size';

  @override
  String get shaderParamColor => 'Color';

  @override
  String get shaderParamFractalSize => 'Complexity (Detail Level)';

  @override
  String get shaderParamFractalDensity => 'Scale (Zoom)';

  @override
  String get shaderParamPsychedelicSize => 'Scale (Zoom)';

  @override
  String get shaderParamPsychedelicDensity => 'Complexity (Detail Level)';

  @override
  String get textStyleSizeLabel => 'Size';

  @override
  String get textStyleAlphaLabel => 'Alpha';

  @override
  String get textStyleTextColor => 'Text';

  @override
  String get textStyleBoxColor => 'Box';

  @override
  String get textStyleOutlineSection => 'Outline';

  @override
  String get textStyleOutlineWidth => 'Width';

  @override
  String get textStyleOutlineColor => 'Color';

  @override
  String get textStyleShadowGlowSection => 'Shadow & Glow';

  @override
  String get textStyleShadowBlur => 'Blur';

  @override
  String get textStyleShadowOffsetX => 'Offset X';

  @override
  String get textStyleShadowOffsetY => 'Offset Y';

  @override
  String get textStyleGlowRadius => 'Glow Radius';

  @override
  String get textStyleShadowColor => 'Shadow';

  @override
  String get textStyleGlowColor => 'Glow';

  @override
  String get textStyleBoxBackgroundSection => 'Box Background';

  @override
  String get textStyleBoxBorderWidth => 'Border';

  @override
  String get textStyleBoxCornerRadius => 'Radius';

  @override
  String get textStylePreviewLabel => 'Preview';

  @override
  String get textStyleSubmenuStyleTooltip => 'Style';

  @override
  String get textStyleSubmenuEffectsTooltip => 'Effects';

  @override
  String get textStyleSubmenuAnimationTooltip => 'Animation';

  @override
  String get textStyleFontLabel => 'Font:';

  @override
  String get textStyleEnableBoxLabel => 'Enable Box:';

  @override
  String get textEffectHeader => 'Effect:';

  @override
  String get textEffectPresetHeader => 'Preset:';

  @override
  String get textEffectStrengthLabel => 'Strength';

  @override
  String get textEffectSpeedLabel => 'Speed';

  @override
  String get textEffectAngleLabel => 'Angle';

  @override
  String get textEffectThicknessLabel => 'Thickness';

  @override
  String get textEffectPresetNeon => 'NEON';

  @override
  String get textEffectPresetRainbow => 'RAINBOW';

  @override
  String get textEffectPresetMetal => 'METAL';

  @override
  String get textEffectPresetWave => 'WAVE';

  @override
  String get textEffectPresetGlitch => 'GLITCH';

  @override
  String get textEffectNameGradient => 'GRADIENT';

  @override
  String get textEffectNameWave => 'WAVE';

  @override
  String get textEffectNameGlitch => 'GLITCH';

  @override
  String get textEffectNameNeon => 'NEON';

  @override
  String get textEffectNameMetal => 'METAL';

  @override
  String get textEffectNameRainbow => 'RAINBOW';

  @override
  String get textEffectNameChrome => 'CHROME';

  @override
  String get textEffectNameScanlines => 'SCANLINES';

  @override
  String get textEffectNameRgbShift => 'RGB SHIFT';

  @override
  String get textEffectNameDuotone => 'DUOTONE';

  @override
  String get textEffectNameHolo => 'HOLO';

  @override
  String get textEffectNameNoiseFlow => 'NOISE FLOW';

  @override
  String get textEffectNameSparkle => 'SPARKLE';

  @override
  String get textEffectNameLiquid => 'LIQUID';

  @override
  String get textEffectNameInnerGlow => 'INNER GLOW';

  @override
  String get textEffectNameInnerShadow => 'INNER SHADOW';

  @override
  String get textEffectNameNone => 'NONE';

  @override
  String get textAnimHeader => 'Animation:';

  @override
  String get textAnimSpeedLabel => 'Speed';

  @override
  String get textAnimAmplitudeLabel => 'Amplitude';

  @override
  String get textAnimPhaseLabel => 'Phase';

  @override
  String get textAnimNameTypeDelete => 'TYPE/DELETE';

  @override
  String get textAnimNameSlideLr => 'SLIDE L-R';

  @override
  String get textAnimNameSlideRl => 'SLIDE R-L';

  @override
  String get textAnimNameShakeH => 'SHAKE H';

  @override
  String get textAnimNameShakeV => 'SHAKE V';

  @override
  String get textAnimNameScanRl => 'SCAN R-L';

  @override
  String get textAnimNameSweepLrRl => 'SWEEP LR-RL';

  @override
  String get textAnimNameGlowPulse => 'GLOW PULSE';

  @override
  String get textAnimNameOutlinePulse => 'OUTLINE PULSE';

  @override
  String get textAnimNameShadowSwing => 'SHADOW SWING';

  @override
  String get textAnimNameFadeIn => 'FADE IN';

  @override
  String get textAnimNameZoomIn => 'ZOOM IN';

  @override
  String get textAnimNameSlideUp => 'SLIDE UP';

  @override
  String get textAnimNameBlurIn => 'BLUR IN';

  @override
  String get textAnimNameScramble => 'SCRAMBLE';

  @override
  String get textAnimNameFlipX => 'FLIP X';

  @override
  String get textAnimNameFlipY => 'FLIP Y';

  @override
  String get textAnimNamePopIn => 'POP IN';

  @override
  String get textAnimNameRubberBand => 'RUBBER BAND';

  @override
  String get textAnimNameWobble => 'WOBBLE';

  @override
  String get textPlayerHintEdit => 'Click to edit text';

  @override
  String get videoSettingsAspectRatioLabel => 'Aspect Ratio:';

  @override
  String get videoSettingsCropModeLabel => 'Crop Mode:';

  @override
  String get videoSettingsRotationLabel => 'Rotation:';

  @override
  String get videoSettingsFlipLabel => 'Flip:';

  @override
  String get videoSettingsBackgroundLabel => 'Background:';

  @override
  String get videoSettingsCropModeFit => 'Fit';

  @override
  String get videoSettingsCropModeFill => 'Fill';

  @override
  String get videoSettingsCropModeStretch => 'Stretch';

  @override
  String get videoSettingsBackgroundBlack => 'Black';

  @override
  String get videoSettingsBackgroundWhite => 'White';

  @override
  String get videoSettingsBackgroundGray => 'Gray';

  @override
  String get videoSettingsBackgroundBlue => 'Blue';

  @override
  String get videoSettingsBackgroundGreen => 'Green';

  @override
  String get videoSettingsBackgroundRed => 'Red';

  @override
  String get videoSpeedTitle => 'Playback Speed';

  @override
  String get videoSpeedRippleLabel => 'Ripple (move following clips)';

  @override
  String get videoSpeedNote =>
      'Note: Preview plays audio with player speed. Export matches speed using FFmpeg atempo.';

  @override
  String get videoSettingsFlipHorizontal => 'Horizontal';

  @override
  String get videoSettingsFlipVertical => 'Vertical';

  @override
  String get visualizerSubmenuCanvasTooltip => 'Canvas Effects';

  @override
  String get visualizerSubmenuProgressTooltip => 'Progress Bars';

  @override
  String get visualizerSubmenuShaderTooltip => 'Shader Effects';

  @override
  String get visualizerSubmenuVisualTooltip => 'Visual Backgrounds';

  @override
  String get visualizerSubmenuSettingsTooltip => 'All Settings';

  @override
  String get visualizerAudioEmptyTimeline => 'No audio sources in timeline';

  @override
  String get visualizerAudioLabel => 'Audio:';

  @override
  String get visualizerAudioSelectHint => 'Select audio';

  @override
  String get visualizerEffectLabel => 'Effect:';

  @override
  String get visualizerScaleLabel => 'Scale:';

  @override
  String get visualizerBarsLabel => 'Bars:';

  @override
  String get visualizerSpacingLabel => 'Spacing:';

  @override
  String get visualizerHeightLabel => 'Height:';

  @override
  String get visualizerRotationLabel => 'Rotation:';

  @override
  String get visualizerThicknessLabel => 'Thickness:';

  @override
  String get visualizerGlowLabel => 'Glow:';

  @override
  String get visualizerMirrorLabel => 'Mirror:';

  @override
  String get visualizerColorLabel => 'Color';

  @override
  String get textColorLabel => 'Color';

  @override
  String get visualizerGradientLabel => 'Gradient:';

  @override
  String get visualizerBackgroundLabel => 'Background:';

  @override
  String get visualizerIntensityLabel => 'Intensity:';

  @override
  String get visualizerSpeedLabel => 'Speed:';

  @override
  String get visualizerVisualLabel => 'Visual:';

  @override
  String get visualizerTrackOpacityLabel => 'Track opacity:';

  @override
  String get visualizerLabelSizeLabel => 'Label size:';

  @override
  String get visualizerLabelAnimLabel => 'Label animation:';

  @override
  String get visualizerLabelPositionLabel => 'Label position:';

  @override
  String get visualizerStyleLabel => 'Style:';

  @override
  String get visualizerCornerLabel => 'Corner:';

  @override
  String get visualizerGapLabel => 'Gap:';

  @override
  String get visualizerHeadSizeLabel => 'Head size:';

  @override
  String get visualizerHeadAnimLabel => 'Head animation:';

  @override
  String get visualizerHeadEffectLabel => 'Head effect:';

  @override
  String get visualizerPresetsLabel => 'Presets:';

  @override
  String get visualizerTrackLabel => 'Track:';

  @override
  String get visualizerVisualFullscreenTooltip =>
      'Draw visualizer as full-screen overlay';

  @override
  String get visualizerShaderFullscreenTooltip =>
      'Draw visualizer shader as full-screen background';

  @override
  String get visualizerShaderLabel => 'Shader:';

  @override
  String get visualizerShaderOptionBars => 'Bars';

  @override
  String get visualizerShaderOptionCircleBars => 'Circle Bars';

  @override
  String get visualizerShaderOptionCircle => 'Circle';

  @override
  String get visualizerShaderOptionNationCircle => 'Nation Circle';

  @override
  String get visualizerShaderOptionWaveform => 'Waveform';

  @override
  String get visualizerShaderOptionSmoothCurves => 'Smooth Curves';

  @override
  String get visualizerShaderOptionClaudeSpectrum => 'Claude Spectrum';

  @override
  String get visualizerShaderOptionSinusWaves => 'Sinus Waves';

  @override
  String get visualizerShaderOptionOrb => 'Orb';

  @override
  String get visualizerShaderOptionPyramid => 'Pyramid';

  @override
  String get visualizerThemeLabel => 'Theme:';

  @override
  String get visualizerProgressStyleCapsule => 'Capsule';

  @override
  String get visualizerProgressStyleSegments => 'Segments';

  @override
  String get visualizerProgressStyleSteps => 'Steps';

  @override
  String get visualizerProgressStyleCentered => 'Centered';

  @override
  String get visualizerProgressStyleOutline => 'Outline';

  @override
  String get visualizerProgressStyleThin => 'Thin';

  @override
  String get visualizerHeadAnimNone => 'None';

  @override
  String get visualizerHeadAnimStatic => 'Static';

  @override
  String get visualizerHeadAnimPulse => 'Pulse';

  @override
  String get visualizerHeadAnimSpark => 'Spark';

  @override
  String get visualizerPresetClean => 'Clean';

  @override
  String get visualizerPresetNeonClub => 'Neon club';

  @override
  String get visualizerPresetCinematic => 'Cinematic';

  @override
  String get visualizerPresetGlitchy => 'Glitchy';

  @override
  String get visualizerPresetFireBlast => 'Fire blast';

  @override
  String get visualizerPresetElectricBlue => 'Electric blue';

  @override
  String get visualizerPresetRainbowRoad => 'Rainbow road';

  @override
  String get visualizerPresetSoftPastel => 'Soft pastel';

  @override
  String get visualizerPresetIceCold => 'Ice cold';

  @override
  String get visualizerPresetMatrixCode => 'Matrix code';

  @override
  String get visualizerThemeClassic => 'Classic';

  @override
  String get visualizerThemeFire => 'Fire';

  @override
  String get visualizerThemeElectric => 'Electric';

  @override
  String get visualizerThemeNeon => 'Neon';

  @override
  String get visualizerThemeRainbow => 'Rainbow';

  @override
  String get visualizerThemeGlitch => 'Glitch';

  @override
  String get visualizerThemeSoft => 'Soft';

  @override
  String get visualizerThemeSunset => 'Sunset';

  @override
  String get visualizerThemeIce => 'Ice';

  @override
  String get visualizerThemeMatrix => 'Matrix';

  @override
  String get visualizerLabelSizeSmall => 'Small';

  @override
  String get visualizerLabelSizeNormal => 'Normal';

  @override
  String get visualizerLabelSizeLarge => 'Large';

  @override
  String get visualizerCounterAnimStatic => 'Static';

  @override
  String get visualizerCounterAnimPulse => 'Pulse';

  @override
  String get visualizerCounterAnimFlip => 'Flip';

  @override
  String get visualizerCounterAnimLeaf => 'Leaf';

  @override
  String get visualizerCounterPositionCenter => 'Center';

  @override
  String get visualizerCounterPositionTop => 'Top';

  @override
  String get visualizerCounterPositionBottom => 'Bottom';

  @override
  String get visualizerCounterPositionSides => 'Sides';

  @override
  String get visualizerOverlaySettingsTitle => 'Overlay Settings:';

  @override
  String get visualizerOverlayCenterImageLabel => 'Center Image';

  @override
  String get visualizerOverlayRingColorLabel => 'Ring Color';

  @override
  String get visualizerOverlayBackgroundLabel => 'Background';

  @override
  String get visualizerNoAudioSource => 'No Audio Source';

  @override
  String get mediaOverlaySubmenuTooltip => 'Media Overlay';

  @override
  String get mediaOverlayAnimDurationLabel => 'Anim Duration';

  @override
  String mediaOverlaySourceTitle(int count) {
    return 'Source ($count available)';
  }

  @override
  String get mediaOverlayAddVideo => 'Add Video';

  @override
  String get mediaOverlayAddImage => 'Add Image';

  @override
  String mediaOverlayPositionLabel(String axis) {
    return 'Position $axis';
  }

  @override
  String get mediaOverlayScaleLabel => 'Scale';

  @override
  String get mediaOverlayOpacityLabel => 'Opacity';

  @override
  String get mediaOverlayRotationLabel => 'Rotation';

  @override
  String get mediaOverlayCornerLabel => 'Corner';

  @override
  String get mediaOverlayAnimationLabel => 'Animation:';

  @override
  String get mediaOverlayAnimNone => 'None';

  @override
  String get mediaOverlayAnimFadeIn => 'Fade In';

  @override
  String get mediaOverlayAnimFadeOut => 'Fade Out';

  @override
  String get mediaOverlayAnimSlideLeft => 'Slide ←';

  @override
  String get mediaOverlayAnimSlideRight => 'Slide →';

  @override
  String get mediaOverlayAnimSlideUp => 'Slide ↑';

  @override
  String get mediaOverlayAnimSlideDown => 'Slide ↓';

  @override
  String get mediaOverlayAnimZoomIn => 'Zoom In';

  @override
  String get mediaOverlayAnimZoomOut => 'Zoom Out';

  @override
  String get mediaPickerTitle => '📱 Pick media from device';

  @override
  String mediaPickerLoadedCount(int count) {
    return '$count items loaded';
  }

  @override
  String get mediaPickerSearchHint => 'Search media...';

  @override
  String mediaPickerTabAll(int count) {
    return 'All ($count)';
  }

  @override
  String mediaPickerTabImages(int count) {
    return 'Images ($count)';
  }

  @override
  String mediaPickerTabVideos(int count) {
    return 'Videos ($count)';
  }

  @override
  String mediaPickerTabAudio(int count) {
    return 'Audio ($count)';
  }

  @override
  String get mediaPickerSelectionLabel => 'media selected';

  @override
  String get mediaPickerClearSelection => 'Clear';

  @override
  String get mediaPickerLoading => 'Loading media...';

  @override
  String get mediaPickerEmpty => 'No media found';

  @override
  String get mediaPickerTypeVideo => 'Video';

  @override
  String get mediaPickerTypeImage => 'Image';

  @override
  String get mediaPickerTypeAudio => 'Audio';

  @override
  String mediaPickerAddToProject(int count) {
    return 'Add to project ($count)';
  }

  @override
  String mediaPickerErrorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get visualizerSettingsAdvancedTitle => 'Advanced Settings';

  @override
  String get visualizerSettingsAdvancedSubtitle =>
      'FFT and audio processing parameters';

  @override
  String get visualizerSettingsApplyFftSnack =>
      'FFT recomputing with new parameters...';

  @override
  String get visualizerSettingsApplyFftButton => 'Apply & Recompute FFT';

  @override
  String get visualizerSettingsStaticTitle => 'Static Parameters';

  @override
  String get visualizerSettingsStaticFftSizeLabel => 'FFT Size';

  @override
  String get visualizerSettingsStaticFftSizeValue => '2048';

  @override
  String get visualizerSettingsStaticFftSizeTooltip =>
      'Window size for FFT computation (fixed)';

  @override
  String get visualizerSettingsStaticHopSizeLabel => 'Hop Size';

  @override
  String get visualizerSettingsStaticHopSizeValue => '512';

  @override
  String get visualizerSettingsStaticHopSizeTooltip =>
      'Step size between FFT windows (fixed)';

  @override
  String get visualizerSettingsStaticSampleRateLabel => 'Sample Rate';

  @override
  String get visualizerSettingsStaticSampleRateValue => '44.1 kHz';

  @override
  String get visualizerSettingsStaticSampleRateTooltip =>
      'Audio sampling rate (fixed)';

  @override
  String get visualizerSettingsCacheTitle => 'Cache Status';

  @override
  String get visualizerSettingsClearCacheSnack => 'FFT cache cleared';

  @override
  String get visualizerSettingsClearCacheButton => 'Clear FFT Cache';

  @override
  String get visualizerSettingsPerformanceTitle => 'Performance';

  @override
  String get visualizerSettingsRenderPipelineLabel => 'Render Pipeline';

  @override
  String get visualizerSettingsRenderPipelineCanvas => 'Canvas (CPU)';

  @override
  String get visualizerSettingsRenderPipelineShader => 'Shader (GPU)';

  @override
  String get visualizerSettingsRenderPipelineTooltip =>
      'Current rendering backend';

  @override
  String get visualizerSettingsFftAboutTitle => 'ℹ️ About FFT Processing';

  @override
  String get visualizerSettingsFftAboutBody =>
      'Audio is processed with 2048-point FFT, downsampled to 64 log-scale bands (50Hz-16kHz), normalized per-frame, and smoothed with EMA (α=0.6) for stable visualization.';

  @override
  String get visualizerSettingsPresetsTitle => 'Presets';

  @override
  String get visualizerSettingsPresetsTooltip =>
      'Quick profiles for FFT bands, smoothing and dynamics.';

  @override
  String get visualizerSettingsPresetCinematic => 'Cinematic';

  @override
  String get visualizerSettingsPresetAggressive => 'Aggressive';

  @override
  String get visualizerSettingsPresetLofi => 'Lo-Fi';

  @override
  String get visualizerSettingsPresetBassHeavy => 'Bass Heavy';

  @override
  String get visualizerSettingsPresetVocalFocus => 'Vocal Focus';

  @override
  String visualizerSettingsPresetAppliedSnack(Object preset) {
    return 'Preset \"$preset\" applied. Press \"Apply & Recompute FFT\" for full effect.';
  }

  @override
  String get visualizerSettingsReactivityLabel => 'Reactivity';

  @override
  String get visualizerSettingsReactivityTooltip =>
      'Curve shaping (0.5-2.0). Higher = more aggressive response, lower = softer.';

  @override
  String get visualizerSettingsCacheCachedTitle => 'FFT Data Cached';

  @override
  String get visualizerSettingsCacheProcessingTitle => 'FFT Processing...';

  @override
  String get visualizerSettingsCacheCachedSubtitle =>
      'Audio analysis complete and ready';

  @override
  String get visualizerSettingsCacheProcessingSubtitle =>
      'Audio is being analyzed in background';

  @override
  String get visualizerSettingsFftBandsLabel => 'FFT Bands';

  @override
  String get visualizerSettingsFftBandsTooltip =>
      'Number of frequency bands (32/64/128). More bands = finer detail but slower processing.';

  @override
  String visualizerSettingsFftBandsValue(int bands) {
    return '$bands bands';
  }

  @override
  String get visualizerSettingsSmoothingLabel => 'Smoothing (EMA α)';

  @override
  String get visualizerSettingsSmoothingTooltip =>
      'Temporal smoothing coefficient (0.0-1.0). Higher = faster response, lower = smoother but delayed.';

  @override
  String get visualizerSettingsFrequencyRangeLabel => 'Frequency Range';

  @override
  String get visualizerSettingsFrequencyRangeTooltip =>
      'Analyzed frequency range in Hz. Adjust for bass-heavy (lower min) or treble-focused (higher min) content.';

  @override
  String visualizerSettingsFrequencyMinLabel(int hz) {
    return 'Min: $hz Hz';
  }

  @override
  String visualizerSettingsFrequencyMaxLabel(int hz) {
    return 'Max: $hz Hz';
  }

  @override
  String get visualizerSettingsAnimSmoothnessLabel => 'Animation Smoothness';

  @override
  String get visualizerSettingsAnimSmoothnessTooltip =>
      'Band smoothing (0.0-1.0). Higher = less flicker, more blur between bands.';
}
