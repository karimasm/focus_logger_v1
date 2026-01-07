# BMAD Project Structure

This folder contains project documentation following the BMAD (Breakthrough Method for Agile AI-Driven Development) approach.

## Structure

```
bmad/
├── docs/                    # Core documentation
│   ├── project-brief.md    # Project overview & goals
│   ├── prd.md              # Product Requirements Document
│   ├── architecture.md     # Technical architecture
│   └── development-workflow.md  # Development guide
├── epics/                   # Feature epics
│   └── E005-analytics-insights.md
└── stories/                 # User stories
    └── _template.md        # Story template
```

## How to Use

### Starting a New Feature

1. Check if an epic exists in `epics/`
2. If not, create one following the format
3. Break epic into stories in `stories/`
4. Implement following `docs/development-workflow.md`

### Working with AI

When working with AI coding assistants, share relevant docs:
- `project-brief.md` - For context
- `architecture.md` - For technical decisions
- Relevant epic/story - For requirements

## Quick Links

- [Project Brief](docs/project-brief.md)
- [PRD](docs/prd.md)
- [Architecture](docs/architecture.md)
- [Development Workflow](docs/development-workflow.md)

## Phase Status

| Phase | Feature | Status |
|-------|---------|--------|
| 1 | Activity Logging | ✅ Done |
| 2 | Guided Flows | ✅ Done |
| 3 | To-Do with Alarms | ✅ Done |
| 4 | Idle Detection | ✅ Done |
| 5 | Analytics & Insights | 🔜 Planned |
