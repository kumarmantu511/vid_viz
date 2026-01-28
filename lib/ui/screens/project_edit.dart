import 'package:flutter/material.dart';
import 'package:vidviz/service_locator.dart';
import 'package:vidviz/service/project_service.dart';
import 'package:vidviz/model/project.dart';
import 'package:vidviz/ui/screens/director.dart';
import 'package:vidviz/core/theme.dart' as app_theme;
import 'package:vidviz/l10n/generated/app_localizations.dart';

class ProjectEdit extends StatelessWidget {
  final projectService = locator.get<ProjectService>();

  ProjectEdit(Project? project) {
    if (project == null) {
      projectService.project = projectService.createNew();
    } else {
      projectService.project = project;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    
    return Scaffold(
      backgroundColor: isDark ? app_theme.projectListBg : app_theme.background,
      appBar: AppBar(
        backgroundColor: isDark ? app_theme.projectListBg : app_theme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          (projectService.project!.id == null)
              ? loc.projectEditAppBarNew
              : loc.projectEditAppBarEdit,
          style: TextStyle(
            color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _ProjectEditForm(),
      resizeToAvoidBottomInset: true,
    );
  }
}

class _ProjectEditForm extends StatelessWidget {
  final projectService = locator.get<ProjectService>();
  // Neccesary static
  // https://github.com/flutter/flutter/issues/20042
  static final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final loc = AppLocalizations.of(context);
    
    return GestureDetector(
      child: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.fromLTRB(
            size.width * 0.06,
            size.height * 0.03,
            size.width * 0.06,
            size.height * 0.05,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Title Field
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                      width: 1,
                    ),
                  ),
                  child: TextFormField(
                    initialValue: projectService.project!.title,
                    maxLength: 75,
                    style: TextStyle(
                      color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                      fontSize: 15,
                    ),
                    onSaved: (value) {
                      projectService.project!.title = value!;
                    },
                    decoration: InputDecoration(
                      hintText: loc.projectEditTitleHint,
                      hintStyle: TextStyle(
                        color: isDark ? app_theme.darkTextSecondary.withOpacity(0.6) : app_theme.textSecondary.withOpacity(0.6),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      counterText: '',
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return loc.projectEditTitleValidation;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 20),
                
                // Description Field
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? app_theme.projectListCardBorder : app_theme.border,
                      width: 1,
                    ),
                  ),
                  child: TextFormField(
                    initialValue: projectService.project!.description,
                    maxLines: 4,
                    maxLength: 1000,
                    style: TextStyle(
                      color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                      fontSize: 15,
                    ),
                    onSaved: (value) {
                      projectService.project!.description = value;
                    },
                    decoration: InputDecoration(
                      hintText: loc.projectEditDescriptionHint,
                      hintStyle: TextStyle(
                        color: isDark ? app_theme.darkTextSecondary.withOpacity(0.6) : app_theme.textSecondary.withOpacity(0.6),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                // Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: Container(
                        height: 55,
                        decoration: BoxDecoration(
                          color: isDark ? app_theme.projectListCardBg : app_theme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.close_rounded,
                                  color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.commonCancel,
                                  style: TextStyle(
                                    color: isDark ? app_theme.darkTextPrimary : app_theme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // OK Button
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 55,
                        decoration: BoxDecoration(
                          gradient: app_theme.neonButtonGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: app_theme.neonCyan.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                      // If the form is valid
                      if (_formKey.currentState!.validate()) {
                        // To call onSave in TextFields
                        _formKey.currentState!.save();

                        // To hide soft keyboard
                        FocusScope.of(context).requestFocus(new FocusNode());

                        if (projectService.project!.id == null) {
                          await projectService.insert(projectService.project);
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    DirectorScreen(projectService.project!)),
                          );
                        } else {
                          await projectService.update(projectService.project);
                          Navigator.pop(context);
                        }
                      }
                    },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  (projectService.project!.id == null) ? Icons.add_rounded : Icons.check_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  (projectService.project!.id == null)
                                      ? loc.projectEditCreateButton
                                      : loc.projectEditSaveButton,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      onTap: () {
        // To hide soft keyboard
        FocusScope.of(context).requestFocus(new FocusNode());
      },
    );
  }
}
