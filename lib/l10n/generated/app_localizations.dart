import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSectionTitle;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSubtitleSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get themeSubtitleSystem;

  /// No description provided for @themeOptionSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeOptionSystem;

  /// No description provided for @themeOptionLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeOptionLight;

  /// No description provided for @themeOptionDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeOptionDark;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select application language'**
  String get languageSubtitle;

  /// No description provided for @languageOptionEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageOptionEnglish;

  /// No description provided for @languageOptionTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get languageOptionTurkish;

  /// No description provided for @languageOptionSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageOptionSpanish;

  /// No description provided for @languageOptionPortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languageOptionPortuguese;

  /// No description provided for @languageOptionHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageOptionHindi;

  /// No description provided for @languageOptionChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageOptionChinese;

  /// No description provided for @languageOptionArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageOptionArabic;

  /// No description provided for @languageOptionFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageOptionFrench;

  /// No description provided for @languageOptionGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageOptionGerman;

  /// No description provided for @languageOptionRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageOptionRussian;

  /// No description provided for @languageOptionJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageOptionJapanese;

  /// No description provided for @languageOptionKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageOptionKorean;

  /// No description provided for @performanceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance & Cache'**
  String get performanceSectionTitle;

  /// No description provided for @clearVisualizerCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear visualizer cache'**
  String get clearVisualizerCacheTitle;

  /// No description provided for @clearVisualizerCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discard precomputed FFT data'**
  String get clearVisualizerCacheSubtitle;

  /// No description provided for @clearVisualizerCacheSnack.
  ///
  /// In en, this message translates to:
  /// **'Visualizer cache cleared'**
  String get clearVisualizerCacheSnack;

  /// No description provided for @clearAudioReactiveCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear audio reactive cache'**
  String get clearAudioReactiveCacheTitle;

  /// No description provided for @clearAudioReactiveCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discard cached FFT data'**
  String get clearAudioReactiveCacheSubtitle;

  /// No description provided for @clearAudioReactiveCacheSnack.
  ///
  /// In en, this message translates to:
  /// **'Audio reactive cache cleared'**
  String get clearAudioReactiveCacheSnack;

  /// No description provided for @advancedSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advancedSectionTitle;

  /// No description provided for @resetSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset settings to defaults'**
  String get resetSettingsTitle;

  /// No description provided for @resetSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restore global settings'**
  String get resetSettingsSubtitle;

  /// No description provided for @resetSettingsSnack.
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get resetSettingsSnack;

  /// No description provided for @projectListTitle.
  ///
  /// In en, this message translates to:
  /// **'My Projects'**
  String get projectListTitle;

  /// No description provided for @projectListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet'**
  String get projectListEmpty;

  /// No description provided for @projectListNewProject.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get projectListNewProject;

  /// No description provided for @projectListContinueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue Editing'**
  String get projectListContinueEditing;

  /// No description provided for @projectListDefaultHeadline.
  ///
  /// In en, this message translates to:
  /// **'Professional Editor'**
  String get projectListDefaultHeadline;

  /// No description provided for @projectMenuDesign.
  ///
  /// In en, this message translates to:
  /// **'Design'**
  String get projectMenuDesign;

  /// No description provided for @projectMenuEditInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Info'**
  String get projectMenuEditInfo;

  /// No description provided for @projectMenuVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get projectMenuVideos;

  /// No description provided for @projectMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get projectMenuDelete;

  /// No description provided for @projectDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm delete'**
  String get projectDeleteDialogTitle;

  /// No description provided for @projectDeleteDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to delete this project?'**
  String get projectDeleteDialogMessage;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @projectEditAppBarNew.
  ///
  /// In en, this message translates to:
  /// **'New Project'**
  String get projectEditAppBarNew;

  /// No description provided for @projectEditAppBarEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Project'**
  String get projectEditAppBarEdit;

  /// No description provided for @projectEditTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter project title'**
  String get projectEditTitleHint;

  /// No description provided for @projectEditTitleValidation.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get projectEditTitleValidation;

  /// No description provided for @projectEditDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add description (optional)'**
  String get projectEditDescriptionHint;

  /// No description provided for @projectEditCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get projectEditCreateButton;

  /// No description provided for @projectEditSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get projectEditSaveButton;

  /// No description provided for @directorMissingAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Some assets have been deleted'**
  String get directorMissingAssetsTitle;

  /// No description provided for @directorMissingAssetsMessage.
  ///
  /// In en, this message translates to:
  /// **'To continue you must recover deleted assets on your device or remove them from the timeline (marked in red).'**
  String get directorMissingAssetsMessage;

  /// No description provided for @editorHeaderCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get editorHeaderCloseTooltip;

  /// No description provided for @editorHeaderArchiveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Import/Export Project (.vvz)'**
  String get editorHeaderArchiveTooltip;

  /// No description provided for @editorHeaderViewGeneratedTooltip.
  ///
  /// In en, this message translates to:
  /// **'View Generated Videos'**
  String get editorHeaderViewGeneratedTooltip;

  /// No description provided for @editorHeaderExportTooltip.
  ///
  /// In en, this message translates to:
  /// **'Export Video'**
  String get editorHeaderExportTooltip;

  /// No description provided for @editorHeaderAddVideoFirstTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add video first'**
  String get editorHeaderAddVideoFirstTooltip;

  /// No description provided for @editorGenerateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Generate video'**
  String get editorGenerateTooltip;

  /// No description provided for @editorGenerateFullHdLabel.
  ///
  /// In en, this message translates to:
  /// **'Generate Full HD 1080px'**
  String get editorGenerateFullHdLabel;

  /// No description provided for @editorGenerateHdLabel.
  ///
  /// In en, this message translates to:
  /// **'Generate HD 720px'**
  String get editorGenerateHdLabel;

  /// No description provided for @editorGenerateSdLabel.
  ///
  /// In en, this message translates to:
  /// **'Generate SD 360px'**
  String get editorGenerateSdLabel;

  /// No description provided for @exportSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Video'**
  String get exportSheetTitle;

  /// No description provided for @exportSheetResolutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get exportSheetResolutionLabel;

  /// No description provided for @exportSheetResolutionHelp.
  ///
  /// In en, this message translates to:
  /// **'Higher Resolution: Crystal Clear Playback for large screen'**
  String get exportSheetResolutionHelp;

  /// No description provided for @exportSheetFileFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'File Format'**
  String get exportSheetFileFormatLabel;

  /// No description provided for @exportSheetFpsLabel.
  ///
  /// In en, this message translates to:
  /// **'Frames Per Second'**
  String get exportSheetFpsLabel;

  /// No description provided for @exportSheetFpsHelp.
  ///
  /// In en, this message translates to:
  /// **'Higher frame rate makes smoother animation'**
  String get exportSheetFpsHelp;

  /// No description provided for @exportSheetQualityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quality / Bitrate'**
  String get exportSheetQualityLabel;

  /// No description provided for @exportSheetQualityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get exportSheetQualityLow;

  /// No description provided for @exportSheetQualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get exportSheetQualityMedium;

  /// No description provided for @exportSheetQualityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get exportSheetQualityHigh;

  /// No description provided for @exportSheetButtonExport.
  ///
  /// In en, this message translates to:
  /// **'Export Video'**
  String get exportSheetButtonExport;

  /// No description provided for @videoRes8k.
  ///
  /// In en, this message translates to:
  /// **'8K UHD 4320p'**
  String get videoRes8k;

  /// No description provided for @videoRes6k.
  ///
  /// In en, this message translates to:
  /// **'6K UHD 3456p'**
  String get videoRes6k;

  /// No description provided for @videoRes4k.
  ///
  /// In en, this message translates to:
  /// **'4K UHD 2160p'**
  String get videoRes4k;

  /// No description provided for @videoRes2k.
  ///
  /// In en, this message translates to:
  /// **'2K QHD 1440p'**
  String get videoRes2k;

  /// No description provided for @videoResFullHd.
  ///
  /// In en, this message translates to:
  /// **'Full HD 1080p'**
  String get videoResFullHd;

  /// No description provided for @videoResHd.
  ///
  /// In en, this message translates to:
  /// **'HD 720p'**
  String get videoResHd;

  /// No description provided for @videoResSd.
  ///
  /// In en, this message translates to:
  /// **'SD 360p'**
  String get videoResSd;

  /// No description provided for @videoQualityUltra.
  ///
  /// In en, this message translates to:
  /// **'Ultra Quality'**
  String get videoQualityUltra;

  /// No description provided for @videoQualityStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard Quality'**
  String get videoQualityStandard;

  /// No description provided for @exportLegacyViewVideos.
  ///
  /// In en, this message translates to:
  /// **'View Videos'**
  String get exportLegacyViewVideos;

  /// No description provided for @exportProgressPreprocessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Preprocessing files'**
  String get exportProgressPreprocessingTitle;

  /// No description provided for @exportProgressBuildingTitle.
  ///
  /// In en, this message translates to:
  /// **'Building your video'**
  String get exportProgressBuildingTitle;

  /// No description provided for @exportProgressSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your video has been saved in the gallery'**
  String get exportProgressSavedTitle;

  /// No description provided for @exportProgressErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get exportProgressErrorTitle;

  /// No description provided for @exportProgressErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. We will work on it. Please try again or upgrade to new versions of the app if the error persists.'**
  String get exportProgressErrorMessage;

  /// No description provided for @exportProgressFileOfTotal.
  ///
  /// In en, this message translates to:
  /// **'File {current} of {total}'**
  String exportProgressFileOfTotal(int current, int total);

  /// No description provided for @exportProgressRemaining.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min {seconds} secs remaining'**
  String exportProgressRemaining(int minutes, int seconds);

  /// No description provided for @exportProgressCancelButton.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get exportProgressCancelButton;

  /// No description provided for @exportProgressOpenVideoButton.
  ///
  /// In en, this message translates to:
  /// **'OPEN VIDEO'**
  String get exportProgressOpenVideoButton;

  /// No description provided for @exportVideoListFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated Videos'**
  String get exportVideoListFallbackTitle;

  /// No description provided for @exportVideoListHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Exported Videos'**
  String get exportVideoListHeaderTitle;

  /// No description provided for @exportVideoListEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No exported videos yet'**
  String get exportVideoListEmptyTitle;

  /// No description provided for @exportVideoListEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your exported videos will appear here'**
  String get exportVideoListEmptySubtitle;

  /// No description provided for @exportVideoListFileNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'File Not Found'**
  String get exportVideoListFileNotFoundTitle;

  /// No description provided for @exportVideoListFileNotFoundMessage.
  ///
  /// In en, this message translates to:
  /// **'This video file has been deleted from your device.'**
  String get exportVideoListFileNotFoundMessage;

  /// No description provided for @exportVideoListDeleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Video?'**
  String get exportVideoListDeleteDialogTitle;

  /// No description provided for @exportVideoListDeleteDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get exportVideoListDeleteDialogMessage;

  /// No description provided for @exportVideoListViewGeneratedTooltip.
  ///
  /// In en, this message translates to:
  /// **'View generated videos'**
  String get exportVideoListViewGeneratedTooltip;

  /// No description provided for @exportVideoListCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 videos} =1{1 video} other{{count} videos}}'**
  String exportVideoListCount(int count);

  /// No description provided for @audioMixerTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio Mixer'**
  String get audioMixerTitle;

  /// No description provided for @audioMixerAudioOnlyPlay.
  ///
  /// In en, this message translates to:
  /// **'Audio-only play'**
  String get audioMixerAudioOnlyPlay;

  /// No description provided for @audioMixerUseOriginalVideoAudio.
  ///
  /// In en, this message translates to:
  /// **'Use original video audio'**
  String get audioMixerUseOriginalVideoAudio;

  /// No description provided for @audioMixerNoAudioLayers.
  ///
  /// In en, this message translates to:
  /// **'No audio layers found'**
  String get audioMixerNoAudioLayers;

  /// No description provided for @audioMixerMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get audioMixerMuted;

  /// No description provided for @audioMixerVolumeSuffix.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get audioMixerVolumeSuffix;

  /// No description provided for @audioReactivePresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get audioReactivePresetsTitle;

  /// No description provided for @audioReactivePresetUltraSubtle.
  ///
  /// In en, this message translates to:
  /// **'Ultra Subtle'**
  String get audioReactivePresetUltraSubtle;

  /// No description provided for @audioReactivePresetSubtle.
  ///
  /// In en, this message translates to:
  /// **'Subtle'**
  String get audioReactivePresetSubtle;

  /// No description provided for @audioReactivePresetSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get audioReactivePresetSoft;

  /// No description provided for @audioReactivePresetNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get audioReactivePresetNormal;

  /// No description provided for @audioReactivePresetGroove.
  ///
  /// In en, this message translates to:
  /// **'Groove'**
  String get audioReactivePresetGroove;

  /// No description provided for @audioReactivePresetPunchy.
  ///
  /// In en, this message translates to:
  /// **'Punchy'**
  String get audioReactivePresetPunchy;

  /// No description provided for @audioReactivePresetHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get audioReactivePresetHard;

  /// No description provided for @audioReactivePresetExtreme.
  ///
  /// In en, this message translates to:
  /// **'Extreme'**
  String get audioReactivePresetExtreme;

  /// No description provided for @audioReactivePresetInsane.
  ///
  /// In en, this message translates to:
  /// **'Insane'**
  String get audioReactivePresetInsane;

  /// No description provided for @audioReactivePresetChill.
  ///
  /// In en, this message translates to:
  /// **'Chill'**
  String get audioReactivePresetChill;

  /// No description provided for @audioReactiveSidebarTooltip.
  ///
  /// In en, this message translates to:
  /// **'Audio Reactive'**
  String get audioReactiveSidebarTooltip;

  /// No description provided for @audioReactiveTargetOverlayLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Overlay'**
  String get audioReactiveTargetOverlayLabel;

  /// No description provided for @audioReactiveNoOverlays.
  ///
  /// In en, this message translates to:
  /// **'No overlays available'**
  String get audioReactiveNoOverlays;

  /// No description provided for @audioReactiveOverlayTypeMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get audioReactiveOverlayTypeMedia;

  /// No description provided for @audioReactiveOverlayTypeAudioReactive.
  ///
  /// In en, this message translates to:
  /// **'Audio Reactive'**
  String get audioReactiveOverlayTypeAudioReactive;

  /// No description provided for @audioReactiveOverlayTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get audioReactiveOverlayTypeText;

  /// No description provided for @audioReactiveOverlayTypeVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get audioReactiveOverlayTypeVisualizer;

  /// No description provided for @audioReactiveOverlayTypeShader.
  ///
  /// In en, this message translates to:
  /// **'Shader'**
  String get audioReactiveOverlayTypeShader;

  /// No description provided for @audioReactiveOverlayTypeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get audioReactiveOverlayTypeUnknown;

  /// No description provided for @audioReactiveOverlayUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed'**
  String get audioReactiveOverlayUnnamed;

  /// No description provided for @audioReactiveAudioSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio Source'**
  String get audioReactiveAudioSourceLabel;

  /// No description provided for @audioReactiveAudioSourceMixed.
  ///
  /// In en, this message translates to:
  /// **'All Audio (Mixed)'**
  String get audioReactiveAudioSourceMixed;

  /// No description provided for @audioReactiveAudioSourceUnnamed.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Audio'**
  String get audioReactiveAudioSourceUnnamed;

  /// No description provided for @audioReactiveNoDedicatedTracks.
  ///
  /// In en, this message translates to:
  /// **'No dedicated audio tracks found. Using global mix.'**
  String get audioReactiveNoDedicatedTracks;

  /// No description provided for @audioReactiveReactiveTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reactive Type:'**
  String get audioReactiveReactiveTypeLabel;

  /// No description provided for @audioReactiveReactiveTypeScale.
  ///
  /// In en, this message translates to:
  /// **'Scale (Grow/Shrink)'**
  String get audioReactiveReactiveTypeScale;

  /// No description provided for @audioReactiveReactiveTypeRotation.
  ///
  /// In en, this message translates to:
  /// **'Rotation (Rotate)'**
  String get audioReactiveReactiveTypeRotation;

  /// No description provided for @audioReactiveReactiveTypeOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity (Transparency)'**
  String get audioReactiveReactiveTypeOpacity;

  /// No description provided for @audioReactiveReactiveTypePosX.
  ///
  /// In en, this message translates to:
  /// **'Position X (Horizontal)'**
  String get audioReactiveReactiveTypePosX;

  /// No description provided for @audioReactiveReactiveTypePosY.
  ///
  /// In en, this message translates to:
  /// **'Position Y (Vertical)'**
  String get audioReactiveReactiveTypePosY;

  /// No description provided for @audioReactiveReactiveTypeFallback.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get audioReactiveReactiveTypeFallback;

  /// No description provided for @audioReactiveSensitivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity'**
  String get audioReactiveSensitivityLabel;

  /// No description provided for @audioReactiveFrequencyRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency Range'**
  String get audioReactiveFrequencyRangeLabel;

  /// No description provided for @audioReactiveFrequencyAll.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get audioReactiveFrequencyAll;

  /// No description provided for @audioReactiveFrequencyBass.
  ///
  /// In en, this message translates to:
  /// **'BASS'**
  String get audioReactiveFrequencyBass;

  /// No description provided for @audioReactiveFrequencyMid.
  ///
  /// In en, this message translates to:
  /// **'MID'**
  String get audioReactiveFrequencyMid;

  /// No description provided for @audioReactiveFrequencyTreble.
  ///
  /// In en, this message translates to:
  /// **'TREBLE'**
  String get audioReactiveFrequencyTreble;

  /// No description provided for @audioReactiveSmoothingLabel.
  ///
  /// In en, this message translates to:
  /// **'Smoothing'**
  String get audioReactiveSmoothingLabel;

  /// No description provided for @audioReactiveDelayLabel.
  ///
  /// In en, this message translates to:
  /// **'Delay'**
  String get audioReactiveDelayLabel;

  /// No description provided for @audioReactiveMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get audioReactiveMinLabel;

  /// No description provided for @audioReactiveMaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get audioReactiveMaxLabel;

  /// No description provided for @audioReactiveInvertLabel.
  ///
  /// In en, this message translates to:
  /// **'Invert Reaction'**
  String get audioReactiveInvertLabel;

  /// No description provided for @audioReactiveOn.
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get audioReactiveOn;

  /// No description provided for @audioReactiveOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get audioReactiveOff;

  /// No description provided for @editorFadeTitle.
  ///
  /// In en, this message translates to:
  /// **'Fade In / Out'**
  String get editorFadeTitle;

  /// No description provided for @editorVolumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Asset Volume'**
  String get editorVolumeTitle;

  /// No description provided for @editorVolumeMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get editorVolumeMute;

  /// No description provided for @editorVolumeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get editorVolumeReset;

  /// No description provided for @editorActionVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get editorActionVideo;

  /// No description provided for @editorActionImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get editorActionImage;

  /// No description provided for @editorActionAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get editorActionAudio;

  /// No description provided for @editorActionText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get editorActionText;

  /// No description provided for @editorActionVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Visualizer'**
  String get editorActionVisualizer;

  /// No description provided for @editorActionShader.
  ///
  /// In en, this message translates to:
  /// **'Shader'**
  String get editorActionShader;

  /// No description provided for @editorActionMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get editorActionMedia;

  /// No description provided for @editorActionReactive.
  ///
  /// In en, this message translates to:
  /// **'Reactive'**
  String get editorActionReactive;

  /// No description provided for @editorActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get editorActionDelete;

  /// No description provided for @editorActionSplit.
  ///
  /// In en, this message translates to:
  /// **'Split'**
  String get editorActionSplit;

  /// No description provided for @editorActionClone.
  ///
  /// In en, this message translates to:
  /// **'Clone'**
  String get editorActionClone;

  /// No description provided for @editorActionSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get editorActionSettings;

  /// No description provided for @editorActionVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get editorActionVolume;

  /// No description provided for @editorActionFade.
  ///
  /// In en, this message translates to:
  /// **'Fade'**
  String get editorActionFade;

  /// No description provided for @editorActionSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get editorActionSpeed;

  /// No description provided for @editorActionReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get editorActionReplace;

  /// No description provided for @editorActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editorActionEdit;

  /// No description provided for @colorEditorSelect.
  ///
  /// In en, this message translates to:
  /// **'SELECT'**
  String get colorEditorSelect;

  /// No description provided for @mediaPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Media permission is required!'**
  String get mediaPermissionRequired;

  /// No description provided for @archiveHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive Manager'**
  String get archiveHeaderTitle;

  /// No description provided for @archiveExportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Export Project (.vvz)'**
  String get archiveExportSectionTitle;

  /// No description provided for @archiveTargetFolderLabel.
  ///
  /// In en, this message translates to:
  /// **'Target folder'**
  String get archiveTargetFolderLabel;

  /// No description provided for @archiveTargetFolderResolving.
  ///
  /// In en, this message translates to:
  /// **'Resolving default...'**
  String get archiveTargetFolderResolving;

  /// No description provided for @archiveTargetFolderDefault.
  ///
  /// In en, this message translates to:
  /// **'Downloads (auto)'**
  String get archiveTargetFolderDefault;

  /// No description provided for @archiveChooseFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get archiveChooseFolder;

  /// No description provided for @archiveResetFolder.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get archiveResetFolder;

  /// No description provided for @archiveIosFolderUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Folder selection is not supported on iOS. Using default.'**
  String get archiveIosFolderUnsupported;

  /// No description provided for @archiveStatsTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get archiveStatsTotalLabel;

  /// No description provided for @archiveStatsVideosLabel.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get archiveStatsVideosLabel;

  /// No description provided for @archiveStatsAudiosLabel.
  ///
  /// In en, this message translates to:
  /// **'Audios'**
  String get archiveStatsAudiosLabel;

  /// No description provided for @archiveStatsImagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get archiveStatsImagesLabel;

  /// No description provided for @archiveStatsMissingLabel.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get archiveStatsMissingLabel;

  /// No description provided for @archiveIncludeVideos.
  ///
  /// In en, this message translates to:
  /// **'Include videos'**
  String get archiveIncludeVideos;

  /// No description provided for @archiveIncludeAudios.
  ///
  /// In en, this message translates to:
  /// **'Include audios'**
  String get archiveIncludeAudios;

  /// No description provided for @archiveMaxVideoSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Max video size (MB)'**
  String get archiveMaxVideoSizeLabel;

  /// No description provided for @archiveMaxTotalSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Max total size (MB)'**
  String get archiveMaxTotalSizeLabel;

  /// No description provided for @archiveUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get archiveUnlimited;

  /// No description provided for @archiveUnlimitedHint.
  ///
  /// In en, this message translates to:
  /// **'0 = Unlimited'**
  String get archiveUnlimitedHint;

  /// No description provided for @archiveEstimating.
  ///
  /// In en, this message translates to:
  /// **'Estimating...'**
  String get archiveEstimating;

  /// No description provided for @archiveSizeEstimateNone.
  ///
  /// In en, this message translates to:
  /// **'Size estimate: -'**
  String get archiveSizeEstimateNone;

  /// No description provided for @archiveSizeEstimate.
  ///
  /// In en, this message translates to:
  /// **'Files: {files}, Size: {sizeMb} MB, Skipped: {skipped}'**
  String archiveSizeEstimate(int files, double sizeMb, int skipped);

  /// No description provided for @archiveSizeWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: estimated size exceeds max total. Export will be blocked.'**
  String get archiveSizeWarning;

  /// No description provided for @archiveNoMedia.
  ///
  /// In en, this message translates to:
  /// **'No media to export. Add media or relink missing files.'**
  String get archiveNoMedia;

  /// No description provided for @archiveExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get archiveExportButton;

  /// No description provided for @archiveImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get archiveImportButton;

  /// No description provided for @archiveRelinkButton.
  ///
  /// In en, this message translates to:
  /// **'Relink'**
  String get archiveRelinkButton;

  /// No description provided for @archiveExportedSnack.
  ///
  /// In en, this message translates to:
  /// **'Exported: {path}'**
  String archiveExportedSnack(String path);

  /// No description provided for @archiveImportProjectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Import Project'**
  String get archiveImportProjectDialogTitle;

  /// No description provided for @archiveImportProjectDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Current project has media. How do you want to proceed?'**
  String get archiveImportProjectDialogMessage;

  /// No description provided for @archiveImportProjectCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create new'**
  String get archiveImportProjectCreateNew;

  /// No description provided for @archiveImportProjectReplaceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Replace current'**
  String get archiveImportProjectReplaceCurrent;

  /// No description provided for @archiveImportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Import cancelled'**
  String get archiveImportCancelled;

  /// No description provided for @archiveImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get archiveImportFailed;

  /// No description provided for @archiveExportPathHint.
  ///
  /// In en, this message translates to:
  /// **'Export path: App Documents/exports/<Project><Timestamp>.vvz'**
  String get archiveExportPathHint;

  /// No description provided for @archivePreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get archivePreviewLabel;

  /// No description provided for @archiveProgressPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing files'**
  String get archiveProgressPreparing;

  /// No description provided for @archiveProgressPackaging.
  ///
  /// In en, this message translates to:
  /// **'Packaging project'**
  String get archiveProgressPackaging;

  /// No description provided for @archiveProgressCompressing.
  ///
  /// In en, this message translates to:
  /// **'Compressing'**
  String get archiveProgressCompressing;

  /// No description provided for @archiveProgressExtracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting'**
  String get archiveProgressExtracting;

  /// No description provided for @archiveProgressFinalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing'**
  String get archiveProgressFinalizing;

  /// No description provided for @archiveProgressWorking.
  ///
  /// In en, this message translates to:
  /// **'Working'**
  String get archiveProgressWorking;

  /// No description provided for @archiveProgressCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get archiveProgressCompletedTitle;

  /// No description provided for @archiveProgressErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get archiveProgressErrorTitle;

  /// No description provided for @archiveProgressUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get archiveProgressUnexpectedError;

  /// No description provided for @archiveProgressDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get archiveProgressDone;

  /// No description provided for @archiveProgressOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Open file'**
  String get archiveProgressOpenFile;

  /// No description provided for @archiveProgressShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get archiveProgressShare;

  /// No description provided for @archiveProgressCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get archiveProgressCancel;

  /// No description provided for @archiveProgressHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get archiveProgressHide;

  /// No description provided for @relinkHeaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Relink Missing Media'**
  String get relinkHeaderTitle;

  /// No description provided for @relinkSuccessSnack.
  ///
  /// In en, this message translates to:
  /// **'Successfully relinked {count} item(s)'**
  String relinkSuccessSnack(int count);

  /// No description provided for @relinkNoMatchesSnack.
  ///
  /// In en, this message translates to:
  /// **'No matching files found in selected folder.\nFile names must match exactly.'**
  String get relinkNoMatchesSnack;

  /// No description provided for @relinkErrorScanSnack.
  ///
  /// In en, this message translates to:
  /// **'Error scanning folder: {error}'**
  String relinkErrorScanSnack(String error);

  /// No description provided for @relinkRelinkedSnack.
  ///
  /// In en, this message translates to:
  /// **'Relinked: {fileName}'**
  String relinkRelinkedSnack(String fileName);

  /// No description provided for @relinkSaveAndCloseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Save & Close'**
  String get relinkSaveAndCloseTooltip;

  /// No description provided for @relinkNoMissingMedia.
  ///
  /// In en, this message translates to:
  /// **'No missing or deleted media found.'**
  String get relinkNoMissingMedia;

  /// No description provided for @relinkScanFolderButton.
  ///
  /// In en, this message translates to:
  /// **'Scan folder for missing files'**
  String get relinkScanFolderButton;

  /// No description provided for @relinkRescanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get relinkRescanTooltip;

  /// No description provided for @exportShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Check out my video!'**
  String get exportShareMessage;

  /// No description provided for @exportShareInstagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get exportShareInstagram;

  /// No description provided for @exportShareWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get exportShareWhatsApp;

  /// No description provided for @exportShareTikTok.
  ///
  /// In en, this message translates to:
  /// **'TikTok'**
  String get exportShareTikTok;

  /// No description provided for @exportShareMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get exportShareMore;

  /// No description provided for @exportFullCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel Export'**
  String get exportFullCancelButton;

  /// No description provided for @exportFullCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get exportFullCloseButton;

  /// No description provided for @exportFullDoNotLock.
  ///
  /// In en, this message translates to:
  /// **'Please do not lock screen or switch to other apps'**
  String get exportFullDoNotLock;

  /// No description provided for @playbackPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get playbackPreviewTitle;

  /// No description provided for @shaderSubmenuEffectsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get shaderSubmenuEffectsTooltip;

  /// No description provided for @shaderSubmenuFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get shaderSubmenuFiltersTooltip;

  /// No description provided for @shaderTypeEffectLabel.
  ///
  /// In en, this message translates to:
  /// **'Effect Type'**
  String get shaderTypeEffectLabel;

  /// No description provided for @shaderTypeFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter Type'**
  String get shaderTypeFilterLabel;

  /// No description provided for @shaderEffectTypeRainName.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get shaderEffectTypeRainName;

  /// No description provided for @shaderEffectTypeRainDesc.
  ///
  /// In en, this message translates to:
  /// **'Animated rain drops'**
  String get shaderEffectTypeRainDesc;

  /// No description provided for @shaderEffectTypeRainGlassName.
  ///
  /// In en, this message translates to:
  /// **'Rain Glass'**
  String get shaderEffectTypeRainGlassName;

  /// No description provided for @shaderEffectTypeRainGlassDesc.
  ///
  /// In en, this message translates to:
  /// **'Rain on glass with foggy streaks'**
  String get shaderEffectTypeRainGlassDesc;

  /// No description provided for @shaderEffectTypeSnowName.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get shaderEffectTypeSnowName;

  /// No description provided for @shaderEffectTypeSnowDesc.
  ///
  /// In en, this message translates to:
  /// **'Animated snow flakes'**
  String get shaderEffectTypeSnowDesc;

  /// No description provided for @shaderEffectTypeWaterName.
  ///
  /// In en, this message translates to:
  /// **'Water Ripple'**
  String get shaderEffectTypeWaterName;

  /// No description provided for @shaderEffectTypeWaterDesc.
  ///
  /// In en, this message translates to:
  /// **'Water ripple distortion'**
  String get shaderEffectTypeWaterDesc;

  /// No description provided for @shaderEffectTypeHalftoneName.
  ///
  /// In en, this message translates to:
  /// **'Halftone'**
  String get shaderEffectTypeHalftoneName;

  /// No description provided for @shaderEffectTypeHalftoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Halftone dot raster effect'**
  String get shaderEffectTypeHalftoneDesc;

  /// No description provided for @shaderEffectTypeTilesName.
  ///
  /// In en, this message translates to:
  /// **'Tiles'**
  String get shaderEffectTypeTilesName;

  /// No description provided for @shaderEffectTypeTilesDesc.
  ///
  /// In en, this message translates to:
  /// **'Tiles/mosaic segmentation effect'**
  String get shaderEffectTypeTilesDesc;

  /// No description provided for @shaderEffectTypeCircleRadiusName.
  ///
  /// In en, this message translates to:
  /// **'Circle Radius'**
  String get shaderEffectTypeCircleRadiusName;

  /// No description provided for @shaderEffectTypeCircleRadiusDesc.
  ///
  /// In en, this message translates to:
  /// **'Circle pixelization based on luminance'**
  String get shaderEffectTypeCircleRadiusDesc;

  /// No description provided for @shaderEffectTypeDunesName.
  ///
  /// In en, this message translates to:
  /// **'Dunes'**
  String get shaderEffectTypeDunesName;

  /// No description provided for @shaderEffectTypeDunesDesc.
  ///
  /// In en, this message translates to:
  /// **'Dunes-like quantization look'**
  String get shaderEffectTypeDunesDesc;

  /// No description provided for @shaderEffectTypeHeatVisionName.
  ///
  /// In en, this message translates to:
  /// **'Heat Vision'**
  String get shaderEffectTypeHeatVisionName;

  /// No description provided for @shaderEffectTypeHeatVisionDesc.
  ///
  /// In en, this message translates to:
  /// **'Heat map style color mapping'**
  String get shaderEffectTypeHeatVisionDesc;

  /// No description provided for @shaderEffectTypeSpectrumName.
  ///
  /// In en, this message translates to:
  /// **'Spectrum Shift'**
  String get shaderEffectTypeSpectrumName;

  /// No description provided for @shaderEffectTypeSpectrumDesc.
  ///
  /// In en, this message translates to:
  /// **'RGB spectrum shift/aberration'**
  String get shaderEffectTypeSpectrumDesc;

  /// No description provided for @shaderEffectTypeWaveWaterName.
  ///
  /// In en, this message translates to:
  /// **'Wave Water'**
  String get shaderEffectTypeWaveWaterName;

  /// No description provided for @shaderEffectTypeWaveWaterDesc.
  ///
  /// In en, this message translates to:
  /// **'Simple water wave refraction'**
  String get shaderEffectTypeWaveWaterDesc;

  /// No description provided for @shaderEffectTypeWater2dName.
  ///
  /// In en, this message translates to:
  /// **'Water 2D'**
  String get shaderEffectTypeWater2dName;

  /// No description provided for @shaderEffectTypeWater2dDesc.
  ///
  /// In en, this message translates to:
  /// **'Fast 2D water lens distortion'**
  String get shaderEffectTypeWater2dDesc;

  /// No description provided for @shaderEffectTypeSphereName.
  ///
  /// In en, this message translates to:
  /// **'Sphere'**
  String get shaderEffectTypeSphereName;

  /// No description provided for @shaderEffectTypeSphereDesc.
  ///
  /// In en, this message translates to:
  /// **'Spinning sphere overlay simulation'**
  String get shaderEffectTypeSphereDesc;

  /// No description provided for @shaderEffectTypeFisheName.
  ///
  /// In en, this message translates to:
  /// **'Fisheye FX'**
  String get shaderEffectTypeFisheName;

  /// No description provided for @shaderEffectTypeFisheDesc.
  ///
  /// In en, this message translates to:
  /// **'Fisheye distortion with chromatic aberration'**
  String get shaderEffectTypeFisheDesc;

  /// No description provided for @shaderEffectTypeHdBoostName.
  ///
  /// In en, this message translates to:
  /// **'HD Boost'**
  String get shaderEffectTypeHdBoostName;

  /// No description provided for @shaderEffectTypeHdBoostDesc.
  ///
  /// In en, this message translates to:
  /// **'Boosts sharpness and micro-contrast'**
  String get shaderEffectTypeHdBoostDesc;

  /// No description provided for @shaderEffectTypeSharpenName.
  ///
  /// In en, this message translates to:
  /// **'Sharpen'**
  String get shaderEffectTypeSharpenName;

  /// No description provided for @shaderEffectTypeSharpenDesc.
  ///
  /// In en, this message translates to:
  /// **'Basic sharpening (unsharp mask variant)'**
  String get shaderEffectTypeSharpenDesc;

  /// No description provided for @shaderEffectTypeEdgeDetectName.
  ///
  /// In en, this message translates to:
  /// **'Edge Detect'**
  String get shaderEffectTypeEdgeDetectName;

  /// No description provided for @shaderEffectTypeEdgeDetectDesc.
  ///
  /// In en, this message translates to:
  /// **'Sobel-based edge detection'**
  String get shaderEffectTypeEdgeDetectDesc;

  /// No description provided for @shaderEffectTypePixelateName.
  ///
  /// In en, this message translates to:
  /// **'Pixelate'**
  String get shaderEffectTypePixelateName;

  /// No description provided for @shaderEffectTypePixelateDesc.
  ///
  /// In en, this message translates to:
  /// **'Large pixel blocks posterized look'**
  String get shaderEffectTypePixelateDesc;

  /// No description provided for @shaderEffectTypePosterizeName.
  ///
  /// In en, this message translates to:
  /// **'Posterize'**
  String get shaderEffectTypePosterizeName;

  /// No description provided for @shaderEffectTypePosterizeDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduces color levels (posterize)'**
  String get shaderEffectTypePosterizeDesc;

  /// No description provided for @shaderEffectTypeChromAberrationName.
  ///
  /// In en, this message translates to:
  /// **'Chromatic Aberration'**
  String get shaderEffectTypeChromAberrationName;

  /// No description provided for @shaderEffectTypeChromAberrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Offsets color channels outward (lens CA)'**
  String get shaderEffectTypeChromAberrationDesc;

  /// No description provided for @shaderEffectTypeCrtName.
  ///
  /// In en, this message translates to:
  /// **'CRT Display'**
  String get shaderEffectTypeCrtName;

  /// No description provided for @shaderEffectTypeCrtDesc.
  ///
  /// In en, this message translates to:
  /// **'Old CRT display (scanlines + barrel distortion)'**
  String get shaderEffectTypeCrtDesc;

  /// No description provided for @shaderEffectTypeSwirlName.
  ///
  /// In en, this message translates to:
  /// **'Swirl'**
  String get shaderEffectTypeSwirlName;

  /// No description provided for @shaderEffectTypeSwirlDesc.
  ///
  /// In en, this message translates to:
  /// **'Swirl distortion around center'**
  String get shaderEffectTypeSwirlDesc;

  /// No description provided for @shaderEffectTypeFisheyeName.
  ///
  /// In en, this message translates to:
  /// **'Fisheye'**
  String get shaderEffectTypeFisheyeName;

  /// No description provided for @shaderEffectTypeFisheyeDesc.
  ///
  /// In en, this message translates to:
  /// **'Fisheye (barrel) distortion'**
  String get shaderEffectTypeFisheyeDesc;

  /// No description provided for @shaderEffectTypeZoomBlurName.
  ///
  /// In en, this message translates to:
  /// **'Zoom Blur'**
  String get shaderEffectTypeZoomBlurName;

  /// No description provided for @shaderEffectTypeZoomBlurDesc.
  ///
  /// In en, this message translates to:
  /// **'Radial zoom blur towards center'**
  String get shaderEffectTypeZoomBlurDesc;

  /// No description provided for @shaderEffectTypeFilmGrainName.
  ///
  /// In en, this message translates to:
  /// **'Film Grain'**
  String get shaderEffectTypeFilmGrainName;

  /// No description provided for @shaderEffectTypeFilmGrainDesc.
  ///
  /// In en, this message translates to:
  /// **'Subtle animated film grain'**
  String get shaderEffectTypeFilmGrainDesc;

  /// No description provided for @shaderEffectTypeBlurName.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get shaderEffectTypeBlurName;

  /// No description provided for @shaderEffectTypeBlurDesc.
  ///
  /// In en, this message translates to:
  /// **'Gaussian blur'**
  String get shaderEffectTypeBlurDesc;

  /// No description provided for @shaderEffectTypeVignetteName.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get shaderEffectTypeVignetteName;

  /// No description provided for @shaderEffectTypeVignetteDesc.
  ///
  /// In en, this message translates to:
  /// **'Cinematic vignette'**
  String get shaderEffectTypeVignetteDesc;

  /// No description provided for @mediaPickerFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get mediaPickerFiles;

  /// No description provided for @mediaPickerAlbumCount.
  ///
  /// In en, this message translates to:
  /// **'{albumName} • {count} Media'**
  String mediaPickerAlbumCount(String albumName, int count);

  /// No description provided for @mediaPickerSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Selected'**
  String mediaPickerSelectedCount(int count);

  /// No description provided for @mediaPermissionDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Cannot Access Gallery'**
  String get mediaPermissionDeniedTitle;

  /// No description provided for @mediaPermissionDeniedMessage.
  ///
  /// In en, this message translates to:
  /// **'We need permission to access your photos and videos.'**
  String get mediaPermissionDeniedMessage;

  /// No description provided for @mediaPermissionManageButton.
  ///
  /// In en, this message translates to:
  /// **'Manage Permissions'**
  String get mediaPermissionManageButton;

  /// No description provided for @mediaPermissionNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get mediaPermissionNotNow;

  /// No description provided for @mediaPickerAudioFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get mediaPickerAudioFallbackTitle;

  /// No description provided for @shaderParamIntensityShort.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get shaderParamIntensityShort;

  /// No description provided for @shaderParamSpeedShort.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get shaderParamSpeedShort;

  /// No description provided for @shaderParamSizeShort.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get shaderParamSizeShort;

  /// No description provided for @shaderParamDensityShort.
  ///
  /// In en, this message translates to:
  /// **'Density'**
  String get shaderParamDensityShort;

  /// No description provided for @shaderParamAngleShort.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get shaderParamAngleShort;

  /// No description provided for @shaderParamFrequencyShort.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get shaderParamFrequencyShort;

  /// No description provided for @shaderParamAmplitudeShort.
  ///
  /// In en, this message translates to:
  /// **'Amplitude'**
  String get shaderParamAmplitudeShort;

  /// No description provided for @shaderParamBlurShort.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get shaderParamBlurShort;

  /// No description provided for @shaderParamVignetteShort.
  ///
  /// In en, this message translates to:
  /// **'Vignette'**
  String get shaderParamVignetteShort;

  /// No description provided for @shaderParamIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity (Strength)'**
  String get shaderParamIntensity;

  /// No description provided for @shaderParamSpeed.
  ///
  /// In en, this message translates to:
  /// **'Speed (Rate)'**
  String get shaderParamSpeed;

  /// No description provided for @shaderParamSize.
  ///
  /// In en, this message translates to:
  /// **'Size (Scale)'**
  String get shaderParamSize;

  /// No description provided for @shaderParamDensity.
  ///
  /// In en, this message translates to:
  /// **'Density (Amount)'**
  String get shaderParamDensity;

  /// No description provided for @shaderParamAngle.
  ///
  /// In en, this message translates to:
  /// **'Angle (Direction)'**
  String get shaderParamAngle;

  /// No description provided for @shaderParamFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency (Detail)'**
  String get shaderParamFrequency;

  /// No description provided for @shaderParamAmplitude.
  ///
  /// In en, this message translates to:
  /// **'Amplitude (Strength)'**
  String get shaderParamAmplitude;

  /// No description provided for @shaderParamBlurRadius.
  ///
  /// In en, this message translates to:
  /// **'Blur Radius (Amount)'**
  String get shaderParamBlurRadius;

  /// No description provided for @shaderParamVignetteSize.
  ///
  /// In en, this message translates to:
  /// **'Vignette Size'**
  String get shaderParamVignetteSize;

  /// No description provided for @shaderParamColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get shaderParamColor;

  /// No description provided for @shaderParamFractalSize.
  ///
  /// In en, this message translates to:
  /// **'Complexity (Detail Level)'**
  String get shaderParamFractalSize;

  /// No description provided for @shaderParamFractalDensity.
  ///
  /// In en, this message translates to:
  /// **'Scale (Zoom)'**
  String get shaderParamFractalDensity;

  /// No description provided for @shaderParamPsychedelicSize.
  ///
  /// In en, this message translates to:
  /// **'Scale (Zoom)'**
  String get shaderParamPsychedelicSize;

  /// No description provided for @shaderParamPsychedelicDensity.
  ///
  /// In en, this message translates to:
  /// **'Complexity (Detail Level)'**
  String get shaderParamPsychedelicDensity;

  /// No description provided for @textStyleSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get textStyleSizeLabel;

  /// No description provided for @textStyleAlphaLabel.
  ///
  /// In en, this message translates to:
  /// **'Alpha'**
  String get textStyleAlphaLabel;

  /// No description provided for @textStyleTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get textStyleTextColor;

  /// No description provided for @textStyleBoxColor.
  ///
  /// In en, this message translates to:
  /// **'Box'**
  String get textStyleBoxColor;

  /// No description provided for @textStyleOutlineSection.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get textStyleOutlineSection;

  /// No description provided for @textStyleOutlineWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get textStyleOutlineWidth;

  /// No description provided for @textStyleOutlineColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get textStyleOutlineColor;

  /// No description provided for @textStyleShadowGlowSection.
  ///
  /// In en, this message translates to:
  /// **'Shadow & Glow'**
  String get textStyleShadowGlowSection;

  /// No description provided for @textStyleShadowBlur.
  ///
  /// In en, this message translates to:
  /// **'Blur'**
  String get textStyleShadowBlur;

  /// No description provided for @textStyleShadowOffsetX.
  ///
  /// In en, this message translates to:
  /// **'Offset X'**
  String get textStyleShadowOffsetX;

  /// No description provided for @textStyleShadowOffsetY.
  ///
  /// In en, this message translates to:
  /// **'Offset Y'**
  String get textStyleShadowOffsetY;

  /// No description provided for @textStyleGlowRadius.
  ///
  /// In en, this message translates to:
  /// **'Glow Radius'**
  String get textStyleGlowRadius;

  /// No description provided for @textStyleShadowColor.
  ///
  /// In en, this message translates to:
  /// **'Shadow'**
  String get textStyleShadowColor;

  /// No description provided for @textStyleGlowColor.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get textStyleGlowColor;

  /// No description provided for @textStyleBoxBackgroundSection.
  ///
  /// In en, this message translates to:
  /// **'Box Background'**
  String get textStyleBoxBackgroundSection;

  /// No description provided for @textStyleBoxBorderWidth.
  ///
  /// In en, this message translates to:
  /// **'Border'**
  String get textStyleBoxBorderWidth;

  /// No description provided for @textStyleBoxCornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get textStyleBoxCornerRadius;

  /// No description provided for @textStylePreviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get textStylePreviewLabel;

  /// No description provided for @textStyleSubmenuStyleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get textStyleSubmenuStyleTooltip;

  /// No description provided for @textStyleSubmenuEffectsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get textStyleSubmenuEffectsTooltip;

  /// No description provided for @textStyleSubmenuAnimationTooltip.
  ///
  /// In en, this message translates to:
  /// **'Animation'**
  String get textStyleSubmenuAnimationTooltip;

  /// No description provided for @textStyleFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Font:'**
  String get textStyleFontLabel;

  /// No description provided for @textStyleEnableBoxLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable Box:'**
  String get textStyleEnableBoxLabel;

  /// No description provided for @textEffectHeader.
  ///
  /// In en, this message translates to:
  /// **'Effect:'**
  String get textEffectHeader;

  /// No description provided for @textEffectPresetHeader.
  ///
  /// In en, this message translates to:
  /// **'Preset:'**
  String get textEffectPresetHeader;

  /// No description provided for @textEffectStrengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get textEffectStrengthLabel;

  /// No description provided for @textEffectSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get textEffectSpeedLabel;

  /// No description provided for @textEffectAngleLabel.
  ///
  /// In en, this message translates to:
  /// **'Angle'**
  String get textEffectAngleLabel;

  /// No description provided for @textEffectThicknessLabel.
  ///
  /// In en, this message translates to:
  /// **'Thickness'**
  String get textEffectThicknessLabel;

  /// No description provided for @textEffectPresetNeon.
  ///
  /// In en, this message translates to:
  /// **'NEON'**
  String get textEffectPresetNeon;

  /// No description provided for @textEffectPresetRainbow.
  ///
  /// In en, this message translates to:
  /// **'RAINBOW'**
  String get textEffectPresetRainbow;

  /// No description provided for @textEffectPresetMetal.
  ///
  /// In en, this message translates to:
  /// **'METAL'**
  String get textEffectPresetMetal;

  /// No description provided for @textEffectPresetWave.
  ///
  /// In en, this message translates to:
  /// **'WAVE'**
  String get textEffectPresetWave;

  /// No description provided for @textEffectPresetGlitch.
  ///
  /// In en, this message translates to:
  /// **'GLITCH'**
  String get textEffectPresetGlitch;

  /// No description provided for @textEffectNameGradient.
  ///
  /// In en, this message translates to:
  /// **'GRADIENT'**
  String get textEffectNameGradient;

  /// No description provided for @textEffectNameWave.
  ///
  /// In en, this message translates to:
  /// **'WAVE'**
  String get textEffectNameWave;

  /// No description provided for @textEffectNameGlitch.
  ///
  /// In en, this message translates to:
  /// **'GLITCH'**
  String get textEffectNameGlitch;

  /// No description provided for @textEffectNameNeon.
  ///
  /// In en, this message translates to:
  /// **'NEON'**
  String get textEffectNameNeon;

  /// No description provided for @textEffectNameMetal.
  ///
  /// In en, this message translates to:
  /// **'METAL'**
  String get textEffectNameMetal;

  /// No description provided for @textEffectNameRainbow.
  ///
  /// In en, this message translates to:
  /// **'RAINBOW'**
  String get textEffectNameRainbow;

  /// No description provided for @textEffectNameChrome.
  ///
  /// In en, this message translates to:
  /// **'CHROME'**
  String get textEffectNameChrome;

  /// No description provided for @textEffectNameScanlines.
  ///
  /// In en, this message translates to:
  /// **'SCANLINES'**
  String get textEffectNameScanlines;

  /// No description provided for @textEffectNameRgbShift.
  ///
  /// In en, this message translates to:
  /// **'RGB SHIFT'**
  String get textEffectNameRgbShift;

  /// No description provided for @textEffectNameDuotone.
  ///
  /// In en, this message translates to:
  /// **'DUOTONE'**
  String get textEffectNameDuotone;

  /// No description provided for @textEffectNameHolo.
  ///
  /// In en, this message translates to:
  /// **'HOLO'**
  String get textEffectNameHolo;

  /// No description provided for @textEffectNameNoiseFlow.
  ///
  /// In en, this message translates to:
  /// **'NOISE FLOW'**
  String get textEffectNameNoiseFlow;

  /// No description provided for @textEffectNameSparkle.
  ///
  /// In en, this message translates to:
  /// **'SPARKLE'**
  String get textEffectNameSparkle;

  /// No description provided for @textEffectNameLiquid.
  ///
  /// In en, this message translates to:
  /// **'LIQUID'**
  String get textEffectNameLiquid;

  /// No description provided for @textEffectNameInnerGlow.
  ///
  /// In en, this message translates to:
  /// **'INNER GLOW'**
  String get textEffectNameInnerGlow;

  /// No description provided for @textEffectNameInnerShadow.
  ///
  /// In en, this message translates to:
  /// **'INNER SHADOW'**
  String get textEffectNameInnerShadow;

  /// No description provided for @textEffectNameNone.
  ///
  /// In en, this message translates to:
  /// **'NONE'**
  String get textEffectNameNone;

  /// No description provided for @textAnimHeader.
  ///
  /// In en, this message translates to:
  /// **'Animation:'**
  String get textAnimHeader;

  /// No description provided for @textAnimSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get textAnimSpeedLabel;

  /// No description provided for @textAnimAmplitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Amplitude'**
  String get textAnimAmplitudeLabel;

  /// No description provided for @textAnimPhaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Phase'**
  String get textAnimPhaseLabel;

  /// No description provided for @textAnimNameTypeDelete.
  ///
  /// In en, this message translates to:
  /// **'TYPE/DELETE'**
  String get textAnimNameTypeDelete;

  /// No description provided for @textAnimNameSlideLr.
  ///
  /// In en, this message translates to:
  /// **'SLIDE L-R'**
  String get textAnimNameSlideLr;

  /// No description provided for @textAnimNameSlideRl.
  ///
  /// In en, this message translates to:
  /// **'SLIDE R-L'**
  String get textAnimNameSlideRl;

  /// No description provided for @textAnimNameShakeH.
  ///
  /// In en, this message translates to:
  /// **'SHAKE H'**
  String get textAnimNameShakeH;

  /// No description provided for @textAnimNameShakeV.
  ///
  /// In en, this message translates to:
  /// **'SHAKE V'**
  String get textAnimNameShakeV;

  /// No description provided for @textAnimNameScanRl.
  ///
  /// In en, this message translates to:
  /// **'SCAN R-L'**
  String get textAnimNameScanRl;

  /// No description provided for @textAnimNameSweepLrRl.
  ///
  /// In en, this message translates to:
  /// **'SWEEP LR-RL'**
  String get textAnimNameSweepLrRl;

  /// No description provided for @textAnimNameGlowPulse.
  ///
  /// In en, this message translates to:
  /// **'GLOW PULSE'**
  String get textAnimNameGlowPulse;

  /// No description provided for @textAnimNameOutlinePulse.
  ///
  /// In en, this message translates to:
  /// **'OUTLINE PULSE'**
  String get textAnimNameOutlinePulse;

  /// No description provided for @textAnimNameShadowSwing.
  ///
  /// In en, this message translates to:
  /// **'SHADOW SWING'**
  String get textAnimNameShadowSwing;

  /// No description provided for @textAnimNameFadeIn.
  ///
  /// In en, this message translates to:
  /// **'FADE IN'**
  String get textAnimNameFadeIn;

  /// No description provided for @textAnimNameZoomIn.
  ///
  /// In en, this message translates to:
  /// **'ZOOM IN'**
  String get textAnimNameZoomIn;

  /// No description provided for @textAnimNameSlideUp.
  ///
  /// In en, this message translates to:
  /// **'SLIDE UP'**
  String get textAnimNameSlideUp;

  /// No description provided for @textAnimNameBlurIn.
  ///
  /// In en, this message translates to:
  /// **'BLUR IN'**
  String get textAnimNameBlurIn;

  /// No description provided for @textAnimNameScramble.
  ///
  /// In en, this message translates to:
  /// **'SCRAMBLE'**
  String get textAnimNameScramble;

  /// No description provided for @textAnimNameFlipX.
  ///
  /// In en, this message translates to:
  /// **'FLIP X'**
  String get textAnimNameFlipX;

  /// No description provided for @textAnimNameFlipY.
  ///
  /// In en, this message translates to:
  /// **'FLIP Y'**
  String get textAnimNameFlipY;

  /// No description provided for @textAnimNamePopIn.
  ///
  /// In en, this message translates to:
  /// **'POP IN'**
  String get textAnimNamePopIn;

  /// No description provided for @textAnimNameRubberBand.
  ///
  /// In en, this message translates to:
  /// **'RUBBER BAND'**
  String get textAnimNameRubberBand;

  /// No description provided for @textAnimNameWobble.
  ///
  /// In en, this message translates to:
  /// **'WOBBLE'**
  String get textAnimNameWobble;

  /// No description provided for @textPlayerHintEdit.
  ///
  /// In en, this message translates to:
  /// **'Click to edit text'**
  String get textPlayerHintEdit;

  /// No description provided for @videoSettingsAspectRatioLabel.
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio:'**
  String get videoSettingsAspectRatioLabel;

  /// No description provided for @videoSettingsCropModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Crop Mode:'**
  String get videoSettingsCropModeLabel;

  /// No description provided for @videoSettingsRotationLabel.
  ///
  /// In en, this message translates to:
  /// **'Rotation:'**
  String get videoSettingsRotationLabel;

  /// No description provided for @videoSettingsFlipLabel.
  ///
  /// In en, this message translates to:
  /// **'Flip:'**
  String get videoSettingsFlipLabel;

  /// No description provided for @videoSettingsBackgroundLabel.
  ///
  /// In en, this message translates to:
  /// **'Background:'**
  String get videoSettingsBackgroundLabel;

  /// No description provided for @videoSettingsCropModeFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get videoSettingsCropModeFit;

  /// No description provided for @videoSettingsCropModeFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get videoSettingsCropModeFill;

  /// No description provided for @videoSettingsCropModeStretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get videoSettingsCropModeStretch;

  /// No description provided for @videoSettingsBackgroundBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get videoSettingsBackgroundBlack;

  /// No description provided for @videoSettingsBackgroundWhite.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get videoSettingsBackgroundWhite;

  /// No description provided for @videoSettingsBackgroundGray.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get videoSettingsBackgroundGray;

  /// No description provided for @videoSettingsBackgroundBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get videoSettingsBackgroundBlue;

  /// No description provided for @videoSettingsBackgroundGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get videoSettingsBackgroundGreen;

  /// No description provided for @videoSettingsBackgroundRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get videoSettingsBackgroundRed;

  /// No description provided for @videoSpeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback Speed'**
  String get videoSpeedTitle;

  /// No description provided for @videoSpeedRippleLabel.
  ///
  /// In en, this message translates to:
  /// **'Ripple (move following clips)'**
  String get videoSpeedRippleLabel;

  /// No description provided for @videoSpeedNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Preview plays audio with player speed. Export matches speed using FFmpeg atempo.'**
  String get videoSpeedNote;

  /// No description provided for @videoSettingsFlipHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Horizontal'**
  String get videoSettingsFlipHorizontal;

  /// No description provided for @videoSettingsFlipVertical.
  ///
  /// In en, this message translates to:
  /// **'Vertical'**
  String get videoSettingsFlipVertical;

  /// No description provided for @visualizerSubmenuCanvasTooltip.
  ///
  /// In en, this message translates to:
  /// **'Canvas Effects'**
  String get visualizerSubmenuCanvasTooltip;

  /// No description provided for @visualizerSubmenuProgressTooltip.
  ///
  /// In en, this message translates to:
  /// **'Progress Bars'**
  String get visualizerSubmenuProgressTooltip;

  /// No description provided for @visualizerSubmenuShaderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Shader Effects'**
  String get visualizerSubmenuShaderTooltip;

  /// No description provided for @visualizerSubmenuVisualTooltip.
  ///
  /// In en, this message translates to:
  /// **'Visual Backgrounds'**
  String get visualizerSubmenuVisualTooltip;

  /// No description provided for @visualizerSubmenuSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'All Settings'**
  String get visualizerSubmenuSettingsTooltip;

  /// No description provided for @visualizerAudioEmptyTimeline.
  ///
  /// In en, this message translates to:
  /// **'No audio sources in timeline'**
  String get visualizerAudioEmptyTimeline;

  /// No description provided for @visualizerAudioLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio:'**
  String get visualizerAudioLabel;

  /// No description provided for @visualizerAudioSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select audio'**
  String get visualizerAudioSelectHint;

  /// No description provided for @visualizerEffectLabel.
  ///
  /// In en, this message translates to:
  /// **'Effect:'**
  String get visualizerEffectLabel;

  /// No description provided for @visualizerScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Scale:'**
  String get visualizerScaleLabel;

  /// No description provided for @visualizerBarsLabel.
  ///
  /// In en, this message translates to:
  /// **'Bars:'**
  String get visualizerBarsLabel;

  /// No description provided for @visualizerSpacingLabel.
  ///
  /// In en, this message translates to:
  /// **'Spacing:'**
  String get visualizerSpacingLabel;

  /// No description provided for @visualizerHeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height:'**
  String get visualizerHeightLabel;

  /// No description provided for @visualizerRotationLabel.
  ///
  /// In en, this message translates to:
  /// **'Rotation:'**
  String get visualizerRotationLabel;

  /// No description provided for @visualizerThicknessLabel.
  ///
  /// In en, this message translates to:
  /// **'Thickness:'**
  String get visualizerThicknessLabel;

  /// No description provided for @visualizerGlowLabel.
  ///
  /// In en, this message translates to:
  /// **'Glow:'**
  String get visualizerGlowLabel;

  /// No description provided for @visualizerMirrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Mirror:'**
  String get visualizerMirrorLabel;

  /// No description provided for @visualizerColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get visualizerColorLabel;

  /// No description provided for @textColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get textColorLabel;

  /// No description provided for @visualizerGradientLabel.
  ///
  /// In en, this message translates to:
  /// **'Gradient:'**
  String get visualizerGradientLabel;

  /// No description provided for @visualizerBackgroundLabel.
  ///
  /// In en, this message translates to:
  /// **'Background:'**
  String get visualizerBackgroundLabel;

  /// No description provided for @visualizerIntensityLabel.
  ///
  /// In en, this message translates to:
  /// **'Intensity:'**
  String get visualizerIntensityLabel;

  /// No description provided for @visualizerSpeedLabel.
  ///
  /// In en, this message translates to:
  /// **'Speed:'**
  String get visualizerSpeedLabel;

  /// No description provided for @visualizerVisualLabel.
  ///
  /// In en, this message translates to:
  /// **'Visual:'**
  String get visualizerVisualLabel;

  /// No description provided for @visualizerTrackOpacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Track opacity:'**
  String get visualizerTrackOpacityLabel;

  /// No description provided for @visualizerLabelSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Label size:'**
  String get visualizerLabelSizeLabel;

  /// No description provided for @visualizerLabelAnimLabel.
  ///
  /// In en, this message translates to:
  /// **'Label animation:'**
  String get visualizerLabelAnimLabel;

  /// No description provided for @visualizerLabelPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Label position:'**
  String get visualizerLabelPositionLabel;

  /// No description provided for @visualizerStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style:'**
  String get visualizerStyleLabel;

  /// No description provided for @visualizerCornerLabel.
  ///
  /// In en, this message translates to:
  /// **'Corner:'**
  String get visualizerCornerLabel;

  /// No description provided for @visualizerGapLabel.
  ///
  /// In en, this message translates to:
  /// **'Gap:'**
  String get visualizerGapLabel;

  /// No description provided for @visualizerHeadSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Head size:'**
  String get visualizerHeadSizeLabel;

  /// No description provided for @visualizerHeadAnimLabel.
  ///
  /// In en, this message translates to:
  /// **'Head animation:'**
  String get visualizerHeadAnimLabel;

  /// No description provided for @visualizerHeadEffectLabel.
  ///
  /// In en, this message translates to:
  /// **'Head effect:'**
  String get visualizerHeadEffectLabel;

  /// No description provided for @visualizerPresetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Presets:'**
  String get visualizerPresetsLabel;

  /// No description provided for @visualizerTrackLabel.
  ///
  /// In en, this message translates to:
  /// **'Track:'**
  String get visualizerTrackLabel;

  /// No description provided for @visualizerVisualFullscreenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Draw visualizer as full-screen overlay'**
  String get visualizerVisualFullscreenTooltip;

  /// No description provided for @visualizerShaderFullscreenTooltip.
  ///
  /// In en, this message translates to:
  /// **'Draw visualizer shader as full-screen background'**
  String get visualizerShaderFullscreenTooltip;

  /// No description provided for @visualizerShaderLabel.
  ///
  /// In en, this message translates to:
  /// **'Shader:'**
  String get visualizerShaderLabel;

  /// No description provided for @visualizerShaderOptionBars.
  ///
  /// In en, this message translates to:
  /// **'Bars'**
  String get visualizerShaderOptionBars;

  /// No description provided for @visualizerShaderOptionCircleBars.
  ///
  /// In en, this message translates to:
  /// **'Circle Bars'**
  String get visualizerShaderOptionCircleBars;

  /// No description provided for @visualizerShaderOptionCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get visualizerShaderOptionCircle;

  /// No description provided for @visualizerShaderOptionNationCircle.
  ///
  /// In en, this message translates to:
  /// **'Nation Circle'**
  String get visualizerShaderOptionNationCircle;

  /// No description provided for @visualizerShaderOptionWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform'**
  String get visualizerShaderOptionWaveform;

  /// No description provided for @visualizerShaderOptionSmoothCurves.
  ///
  /// In en, this message translates to:
  /// **'Smooth Curves'**
  String get visualizerShaderOptionSmoothCurves;

  /// No description provided for @visualizerShaderOptionClaudeSpectrum.
  ///
  /// In en, this message translates to:
  /// **'Claude Spectrum'**
  String get visualizerShaderOptionClaudeSpectrum;

  /// No description provided for @visualizerShaderOptionSinusWaves.
  ///
  /// In en, this message translates to:
  /// **'Sinus Waves'**
  String get visualizerShaderOptionSinusWaves;

  /// No description provided for @visualizerShaderOptionOrb.
  ///
  /// In en, this message translates to:
  /// **'Orb'**
  String get visualizerShaderOptionOrb;

  /// No description provided for @visualizerShaderOptionPyramid.
  ///
  /// In en, this message translates to:
  /// **'Pyramid'**
  String get visualizerShaderOptionPyramid;

  /// No description provided for @visualizerThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme:'**
  String get visualizerThemeLabel;

  /// No description provided for @visualizerProgressStyleCapsule.
  ///
  /// In en, this message translates to:
  /// **'Capsule'**
  String get visualizerProgressStyleCapsule;

  /// No description provided for @visualizerProgressStyleSegments.
  ///
  /// In en, this message translates to:
  /// **'Segments'**
  String get visualizerProgressStyleSegments;

  /// No description provided for @visualizerProgressStyleSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get visualizerProgressStyleSteps;

  /// No description provided for @visualizerProgressStyleCentered.
  ///
  /// In en, this message translates to:
  /// **'Centered'**
  String get visualizerProgressStyleCentered;

  /// No description provided for @visualizerProgressStyleOutline.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get visualizerProgressStyleOutline;

  /// No description provided for @visualizerProgressStyleThin.
  ///
  /// In en, this message translates to:
  /// **'Thin'**
  String get visualizerProgressStyleThin;

  /// No description provided for @visualizerHeadAnimNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get visualizerHeadAnimNone;

  /// No description provided for @visualizerHeadAnimStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get visualizerHeadAnimStatic;

  /// No description provided for @visualizerHeadAnimPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get visualizerHeadAnimPulse;

  /// No description provided for @visualizerHeadAnimSpark.
  ///
  /// In en, this message translates to:
  /// **'Spark'**
  String get visualizerHeadAnimSpark;

  /// No description provided for @visualizerPresetClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get visualizerPresetClean;

  /// No description provided for @visualizerPresetNeonClub.
  ///
  /// In en, this message translates to:
  /// **'Neon club'**
  String get visualizerPresetNeonClub;

  /// No description provided for @visualizerPresetCinematic.
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get visualizerPresetCinematic;

  /// No description provided for @visualizerPresetGlitchy.
  ///
  /// In en, this message translates to:
  /// **'Glitchy'**
  String get visualizerPresetGlitchy;

  /// No description provided for @visualizerPresetFireBlast.
  ///
  /// In en, this message translates to:
  /// **'Fire blast'**
  String get visualizerPresetFireBlast;

  /// No description provided for @visualizerPresetElectricBlue.
  ///
  /// In en, this message translates to:
  /// **'Electric blue'**
  String get visualizerPresetElectricBlue;

  /// No description provided for @visualizerPresetRainbowRoad.
  ///
  /// In en, this message translates to:
  /// **'Rainbow road'**
  String get visualizerPresetRainbowRoad;

  /// No description provided for @visualizerPresetSoftPastel.
  ///
  /// In en, this message translates to:
  /// **'Soft pastel'**
  String get visualizerPresetSoftPastel;

  /// No description provided for @visualizerPresetIceCold.
  ///
  /// In en, this message translates to:
  /// **'Ice cold'**
  String get visualizerPresetIceCold;

  /// No description provided for @visualizerPresetMatrixCode.
  ///
  /// In en, this message translates to:
  /// **'Matrix code'**
  String get visualizerPresetMatrixCode;

  /// No description provided for @visualizerThemeClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get visualizerThemeClassic;

  /// No description provided for @visualizerThemeFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get visualizerThemeFire;

  /// No description provided for @visualizerThemeElectric.
  ///
  /// In en, this message translates to:
  /// **'Electric'**
  String get visualizerThemeElectric;

  /// No description provided for @visualizerThemeNeon.
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get visualizerThemeNeon;

  /// No description provided for @visualizerThemeRainbow.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get visualizerThemeRainbow;

  /// No description provided for @visualizerThemeGlitch.
  ///
  /// In en, this message translates to:
  /// **'Glitch'**
  String get visualizerThemeGlitch;

  /// No description provided for @visualizerThemeSoft.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get visualizerThemeSoft;

  /// No description provided for @visualizerThemeSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get visualizerThemeSunset;

  /// No description provided for @visualizerThemeIce.
  ///
  /// In en, this message translates to:
  /// **'Ice'**
  String get visualizerThemeIce;

  /// No description provided for @visualizerThemeMatrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix'**
  String get visualizerThemeMatrix;

  /// No description provided for @visualizerLabelSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get visualizerLabelSizeSmall;

  /// No description provided for @visualizerLabelSizeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get visualizerLabelSizeNormal;

  /// No description provided for @visualizerLabelSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get visualizerLabelSizeLarge;

  /// No description provided for @visualizerCounterAnimStatic.
  ///
  /// In en, this message translates to:
  /// **'Static'**
  String get visualizerCounterAnimStatic;

  /// No description provided for @visualizerCounterAnimPulse.
  ///
  /// In en, this message translates to:
  /// **'Pulse'**
  String get visualizerCounterAnimPulse;

  /// No description provided for @visualizerCounterAnimFlip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get visualizerCounterAnimFlip;

  /// No description provided for @visualizerCounterAnimLeaf.
  ///
  /// In en, this message translates to:
  /// **'Leaf'**
  String get visualizerCounterAnimLeaf;

  /// No description provided for @visualizerCounterPositionCenter.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get visualizerCounterPositionCenter;

  /// No description provided for @visualizerCounterPositionTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get visualizerCounterPositionTop;

  /// No description provided for @visualizerCounterPositionBottom.
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get visualizerCounterPositionBottom;

  /// No description provided for @visualizerCounterPositionSides.
  ///
  /// In en, this message translates to:
  /// **'Sides'**
  String get visualizerCounterPositionSides;

  /// No description provided for @visualizerOverlaySettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Overlay Settings:'**
  String get visualizerOverlaySettingsTitle;

  /// No description provided for @visualizerOverlayCenterImageLabel.
  ///
  /// In en, this message translates to:
  /// **'Center Image'**
  String get visualizerOverlayCenterImageLabel;

  /// No description provided for @visualizerOverlayRingColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Ring Color'**
  String get visualizerOverlayRingColorLabel;

  /// No description provided for @visualizerOverlayBackgroundLabel.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get visualizerOverlayBackgroundLabel;

  /// No description provided for @visualizerNoAudioSource.
  ///
  /// In en, this message translates to:
  /// **'No Audio Source'**
  String get visualizerNoAudioSource;

  /// No description provided for @mediaOverlaySubmenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Media Overlay'**
  String get mediaOverlaySubmenuTooltip;

  /// No description provided for @mediaOverlayAnimDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Anim Duration'**
  String get mediaOverlayAnimDurationLabel;

  /// No description provided for @mediaOverlaySourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Source ({count} available)'**
  String mediaOverlaySourceTitle(int count);

  /// No description provided for @mediaOverlayAddVideo.
  ///
  /// In en, this message translates to:
  /// **'Add Video'**
  String get mediaOverlayAddVideo;

  /// No description provided for @mediaOverlayAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get mediaOverlayAddImage;

  /// No description provided for @mediaOverlayPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position {axis}'**
  String mediaOverlayPositionLabel(String axis);

  /// No description provided for @mediaOverlayScaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get mediaOverlayScaleLabel;

  /// No description provided for @mediaOverlayOpacityLabel.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get mediaOverlayOpacityLabel;

  /// No description provided for @mediaOverlayRotationLabel.
  ///
  /// In en, this message translates to:
  /// **'Rotation'**
  String get mediaOverlayRotationLabel;

  /// No description provided for @mediaOverlayCornerLabel.
  ///
  /// In en, this message translates to:
  /// **'Corner'**
  String get mediaOverlayCornerLabel;

  /// No description provided for @mediaOverlayAnimationLabel.
  ///
  /// In en, this message translates to:
  /// **'Animation:'**
  String get mediaOverlayAnimationLabel;

  /// No description provided for @mediaOverlayAnimNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get mediaOverlayAnimNone;

  /// No description provided for @mediaOverlayAnimFadeIn.
  ///
  /// In en, this message translates to:
  /// **'Fade In'**
  String get mediaOverlayAnimFadeIn;

  /// No description provided for @mediaOverlayAnimFadeOut.
  ///
  /// In en, this message translates to:
  /// **'Fade Out'**
  String get mediaOverlayAnimFadeOut;

  /// No description provided for @mediaOverlayAnimSlideLeft.
  ///
  /// In en, this message translates to:
  /// **'Slide ←'**
  String get mediaOverlayAnimSlideLeft;

  /// No description provided for @mediaOverlayAnimSlideRight.
  ///
  /// In en, this message translates to:
  /// **'Slide →'**
  String get mediaOverlayAnimSlideRight;

  /// No description provided for @mediaOverlayAnimSlideUp.
  ///
  /// In en, this message translates to:
  /// **'Slide ↑'**
  String get mediaOverlayAnimSlideUp;

  /// No description provided for @mediaOverlayAnimSlideDown.
  ///
  /// In en, this message translates to:
  /// **'Slide ↓'**
  String get mediaOverlayAnimSlideDown;

  /// No description provided for @mediaOverlayAnimZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get mediaOverlayAnimZoomIn;

  /// No description provided for @mediaOverlayAnimZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get mediaOverlayAnimZoomOut;

  /// No description provided for @mediaPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'📱 Pick media from device'**
  String get mediaPickerTitle;

  /// No description provided for @mediaPickerLoadedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items loaded'**
  String mediaPickerLoadedCount(int count);

  /// No description provided for @mediaPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search media...'**
  String get mediaPickerSearchHint;

  /// No description provided for @mediaPickerTabAll.
  ///
  /// In en, this message translates to:
  /// **'All ({count})'**
  String mediaPickerTabAll(int count);

  /// No description provided for @mediaPickerTabImages.
  ///
  /// In en, this message translates to:
  /// **'Images ({count})'**
  String mediaPickerTabImages(int count);

  /// No description provided for @mediaPickerTabVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos ({count})'**
  String mediaPickerTabVideos(int count);

  /// No description provided for @mediaPickerTabAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio ({count})'**
  String mediaPickerTabAudio(int count);

  /// No description provided for @mediaPickerSelectionLabel.
  ///
  /// In en, this message translates to:
  /// **'media selected'**
  String get mediaPickerSelectionLabel;

  /// No description provided for @mediaPickerClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get mediaPickerClearSelection;

  /// No description provided for @mediaPickerLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading media...'**
  String get mediaPickerLoading;

  /// No description provided for @mediaPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No media found'**
  String get mediaPickerEmpty;

  /// No description provided for @mediaPickerTypeVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaPickerTypeVideo;

  /// No description provided for @mediaPickerTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get mediaPickerTypeImage;

  /// No description provided for @mediaPickerTypeAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get mediaPickerTypeAudio;

  /// No description provided for @mediaPickerAddToProject.
  ///
  /// In en, this message translates to:
  /// **'Add to project ({count})'**
  String mediaPickerAddToProject(int count);

  /// No description provided for @mediaPickerErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String mediaPickerErrorGeneric(String error);

  /// No description provided for @visualizerSettingsAdvancedTitle.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get visualizerSettingsAdvancedTitle;

  /// No description provided for @visualizerSettingsAdvancedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'FFT and audio processing parameters'**
  String get visualizerSettingsAdvancedSubtitle;

  /// No description provided for @visualizerSettingsApplyFftSnack.
  ///
  /// In en, this message translates to:
  /// **'FFT recomputing with new parameters...'**
  String get visualizerSettingsApplyFftSnack;

  /// No description provided for @visualizerSettingsApplyFftButton.
  ///
  /// In en, this message translates to:
  /// **'Apply & Recompute FFT'**
  String get visualizerSettingsApplyFftButton;

  /// No description provided for @visualizerSettingsStaticTitle.
  ///
  /// In en, this message translates to:
  /// **'Static Parameters'**
  String get visualizerSettingsStaticTitle;

  /// No description provided for @visualizerSettingsStaticFftSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'FFT Size'**
  String get visualizerSettingsStaticFftSizeLabel;

  /// No description provided for @visualizerSettingsStaticFftSizeValue.
  ///
  /// In en, this message translates to:
  /// **'2048'**
  String get visualizerSettingsStaticFftSizeValue;

  /// No description provided for @visualizerSettingsStaticFftSizeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Window size for FFT computation (fixed)'**
  String get visualizerSettingsStaticFftSizeTooltip;

  /// No description provided for @visualizerSettingsStaticHopSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Hop Size'**
  String get visualizerSettingsStaticHopSizeLabel;

  /// No description provided for @visualizerSettingsStaticHopSizeValue.
  ///
  /// In en, this message translates to:
  /// **'512'**
  String get visualizerSettingsStaticHopSizeValue;

  /// No description provided for @visualizerSettingsStaticHopSizeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Step size between FFT windows (fixed)'**
  String get visualizerSettingsStaticHopSizeTooltip;

  /// No description provided for @visualizerSettingsStaticSampleRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample Rate'**
  String get visualizerSettingsStaticSampleRateLabel;

  /// No description provided for @visualizerSettingsStaticSampleRateValue.
  ///
  /// In en, this message translates to:
  /// **'44.1 kHz'**
  String get visualizerSettingsStaticSampleRateValue;

  /// No description provided for @visualizerSettingsStaticSampleRateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Audio sampling rate (fixed)'**
  String get visualizerSettingsStaticSampleRateTooltip;

  /// No description provided for @visualizerSettingsCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache Status'**
  String get visualizerSettingsCacheTitle;

  /// No description provided for @visualizerSettingsClearCacheSnack.
  ///
  /// In en, this message translates to:
  /// **'FFT cache cleared'**
  String get visualizerSettingsClearCacheSnack;

  /// No description provided for @visualizerSettingsClearCacheButton.
  ///
  /// In en, this message translates to:
  /// **'Clear FFT Cache'**
  String get visualizerSettingsClearCacheButton;

  /// No description provided for @visualizerSettingsPerformanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get visualizerSettingsPerformanceTitle;

  /// No description provided for @visualizerSettingsRenderPipelineLabel.
  ///
  /// In en, this message translates to:
  /// **'Render Pipeline'**
  String get visualizerSettingsRenderPipelineLabel;

  /// No description provided for @visualizerSettingsRenderPipelineCanvas.
  ///
  /// In en, this message translates to:
  /// **'Canvas (CPU)'**
  String get visualizerSettingsRenderPipelineCanvas;

  /// No description provided for @visualizerSettingsRenderPipelineShader.
  ///
  /// In en, this message translates to:
  /// **'Shader (GPU)'**
  String get visualizerSettingsRenderPipelineShader;

  /// No description provided for @visualizerSettingsRenderPipelineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Current rendering backend'**
  String get visualizerSettingsRenderPipelineTooltip;

  /// No description provided for @visualizerSettingsFftAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'ℹ️ About FFT Processing'**
  String get visualizerSettingsFftAboutTitle;

  /// No description provided for @visualizerSettingsFftAboutBody.
  ///
  /// In en, this message translates to:
  /// **'Audio is processed with 2048-point FFT, downsampled to 64 log-scale bands (50Hz-16kHz), normalized per-frame, and smoothed with EMA (α=0.6) for stable visualization.'**
  String get visualizerSettingsFftAboutBody;

  /// No description provided for @visualizerSettingsPresetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get visualizerSettingsPresetsTitle;

  /// No description provided for @visualizerSettingsPresetsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Quick profiles for FFT bands, smoothing and dynamics.'**
  String get visualizerSettingsPresetsTooltip;

  /// No description provided for @visualizerSettingsPresetCinematic.
  ///
  /// In en, this message translates to:
  /// **'Cinematic'**
  String get visualizerSettingsPresetCinematic;

  /// No description provided for @visualizerSettingsPresetAggressive.
  ///
  /// In en, this message translates to:
  /// **'Aggressive'**
  String get visualizerSettingsPresetAggressive;

  /// No description provided for @visualizerSettingsPresetLofi.
  ///
  /// In en, this message translates to:
  /// **'Lo-Fi'**
  String get visualizerSettingsPresetLofi;

  /// No description provided for @visualizerSettingsPresetBassHeavy.
  ///
  /// In en, this message translates to:
  /// **'Bass Heavy'**
  String get visualizerSettingsPresetBassHeavy;

  /// No description provided for @visualizerSettingsPresetVocalFocus.
  ///
  /// In en, this message translates to:
  /// **'Vocal Focus'**
  String get visualizerSettingsPresetVocalFocus;

  /// No description provided for @visualizerSettingsPresetAppliedSnack.
  ///
  /// In en, this message translates to:
  /// **'Preset \"{preset}\" applied. Press \"Apply & Recompute FFT\" for full effect.'**
  String visualizerSettingsPresetAppliedSnack(Object preset);

  /// No description provided for @visualizerSettingsReactivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Reactivity'**
  String get visualizerSettingsReactivityLabel;

  /// No description provided for @visualizerSettingsReactivityTooltip.
  ///
  /// In en, this message translates to:
  /// **'Curve shaping (0.5-2.0). Higher = more aggressive response, lower = softer.'**
  String get visualizerSettingsReactivityTooltip;

  /// No description provided for @visualizerSettingsCacheCachedTitle.
  ///
  /// In en, this message translates to:
  /// **'FFT Data Cached'**
  String get visualizerSettingsCacheCachedTitle;

  /// No description provided for @visualizerSettingsCacheProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'FFT Processing...'**
  String get visualizerSettingsCacheProcessingTitle;

  /// No description provided for @visualizerSettingsCacheCachedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Audio analysis complete and ready'**
  String get visualizerSettingsCacheCachedSubtitle;

  /// No description provided for @visualizerSettingsCacheProcessingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Audio is being analyzed in background'**
  String get visualizerSettingsCacheProcessingSubtitle;

  /// No description provided for @visualizerSettingsFftBandsLabel.
  ///
  /// In en, this message translates to:
  /// **'FFT Bands'**
  String get visualizerSettingsFftBandsLabel;

  /// No description provided for @visualizerSettingsFftBandsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Number of frequency bands (32/64/128). More bands = finer detail but slower processing.'**
  String get visualizerSettingsFftBandsTooltip;

  /// No description provided for @visualizerSettingsFftBandsValue.
  ///
  /// In en, this message translates to:
  /// **'{bands} bands'**
  String visualizerSettingsFftBandsValue(int bands);

  /// No description provided for @visualizerSettingsSmoothingLabel.
  ///
  /// In en, this message translates to:
  /// **'Smoothing (EMA α)'**
  String get visualizerSettingsSmoothingLabel;

  /// No description provided for @visualizerSettingsSmoothingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Temporal smoothing coefficient (0.0-1.0). Higher = faster response, lower = smoother but delayed.'**
  String get visualizerSettingsSmoothingTooltip;

  /// No description provided for @visualizerSettingsFrequencyRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency Range'**
  String get visualizerSettingsFrequencyRangeLabel;

  /// No description provided for @visualizerSettingsFrequencyRangeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Analyzed frequency range in Hz. Adjust for bass-heavy (lower min) or treble-focused (higher min) content.'**
  String get visualizerSettingsFrequencyRangeTooltip;

  /// No description provided for @visualizerSettingsFrequencyMinLabel.
  ///
  /// In en, this message translates to:
  /// **'Min: {hz} Hz'**
  String visualizerSettingsFrequencyMinLabel(int hz);

  /// No description provided for @visualizerSettingsFrequencyMaxLabel.
  ///
  /// In en, this message translates to:
  /// **'Max: {hz} Hz'**
  String visualizerSettingsFrequencyMaxLabel(int hz);

  /// No description provided for @visualizerSettingsAnimSmoothnessLabel.
  ///
  /// In en, this message translates to:
  /// **'Animation Smoothness'**
  String get visualizerSettingsAnimSmoothnessLabel;

  /// No description provided for @visualizerSettingsAnimSmoothnessTooltip.
  ///
  /// In en, this message translates to:
  /// **'Band smoothing (0.0-1.0). Higher = less flicker, more blur between bands.'**
  String get visualizerSettingsAnimSmoothnessTooltip;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'ja',
    'ko',
    'pt',
    'ru',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
