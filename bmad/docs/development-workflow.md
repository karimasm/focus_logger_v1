# Development Workflow Guide

## BMAD-Inspired Development Process

This project follows a spec-oriented, AI-driven development approach inspired by the BMAD Method.

---

## 1. Planning Phase

### Before Starting Any Feature

1. **Check Epic/Story exists**
   ```
   bmad/epics/       - High-level features
   bmad/stories/     - Detailed user stories
   ```

2. **Create Story if needed**
   - Use template: `bmad/stories/_template.md`
   - Define acceptance criteria
   - Estimate effort

3. **Review Architecture**
   - Check `bmad/docs/architecture.md`
   - Identify affected components
   - Plan database changes if needed

---

## 2. Implementation Phase

### Development Checklist

- [ ] Read existing code in affected files
- [ ] Follow established patterns and conventions
- [ ] Use existing libraries (check pubspec.yaml)
- [ ] Maintain consistent naming
- [ ] Add only necessary comments
- [ ] Handle errors gracefully
- [ ] Consider offline scenarios

### Code Quality

```bash
# Run before committing
flutter analyze
flutter build linux  # or android/ios
```

### Testing

```bash
# Run tests (when available)
flutter test
```

---

## 3. Review Phase

### Before Committing

- [ ] `git diff` - Review all changes
- [ ] `git status` - Check nothing unexpected
- [ ] No secrets/credentials in code
- [ ] Build succeeds
- [ ] Basic manual testing done

### Commit Message Format

```
<type>(<scope>): <description>

<body>

Co-authored-by: factory-droid[bot] <138933559+factory-droid[bot]@users.noreply.github.com>
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`

---

## 4. File Structure

```
focus_logger/
├── bmad/                    # BMAD documentation
│   ├── docs/               # Project specs
│   │   ├── project-brief.md
│   │   ├── prd.md
│   │   └── architecture.md
│   ├── epics/              # Epic definitions
│   └── stories/            # User stories
├── lib/
│   ├── models/             # Data models
│   ├── providers/          # State management
│   ├── screens/            # UI screens
│   ├── widgets/            # Reusable widgets
│   ├── services/           # Business logic
│   ├── data/               # Repository layer
│   ├── database/           # SQLite helpers
│   └── theme/              # Theming
├── assets/                 # Images, sounds
├── supabase_*.sql          # DB migrations
└── pubspec.yaml            # Dependencies
```

---

## 5. Common Patterns

### Adding a New Screen

1. Create `lib/screens/new_screen.dart`
2. Use AppColors for theming
3. Add route in navigation
4. Connect to relevant provider

### Adding a New Model

1. Create `lib/models/new_model.dart`
2. Add toMap/fromMap for serialization
3. Export in `lib/models/models.dart`
4. Add repository methods
5. Create Supabase migration if synced

### Adding a Provider Method

1. Add method to provider class
2. Call repository for persistence
3. Update state and notify listeners
4. Handle errors with try-catch

---

## 6. AI Collaboration Tips

When working with AI coding assistants:

1. **Provide context** - Share relevant files
2. **Be specific** - Define exact requirements
3. **Review output** - AI makes mistakes
4. **Iterate** - Refine through feedback
5. **Document decisions** - Update specs

---

## 7. Database Migrations

### Local (SQLite)

Edit `lib/database/database_helper.dart`:
- Increment `_databaseVersion`
- Add migration in `_onUpgrade`

### Cloud (Supabase)

1. Create `supabase_<feature>_migration.sql`
2. Run in Supabase SQL Editor
3. Test sync functionality

---

## 8. Quick Reference

### Key Commands

```bash
# Build
flutter build linux --release
flutter build apk --release

# Run
flutter run -d linux
flutter run -d <device_id>

# Clean
flutter clean && flutter pub get

# Analyze
flutter analyze
```

### Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point |
| `lib/app.dart` | App configuration |
| `lib/theme/colors.dart` | Color system |
| `pubspec.yaml` | Dependencies |
| `.env` | Supabase credentials |
