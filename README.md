# ai_nutrition_assistant

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## FatSecret Functions Deploy

Use the guarded deploy script to deploy only FatSecret-backed functions:

```bash
./scripts/deploy_fatsecret_functions.sh
```

What it checks before deploy:
- You are not on `main` (unless `--allow-main`).
- Your branch is not behind `origin/main`.
- Working tree is clean (unless `--allow-dirty`).
- GitHub check runs for the current commit are passing (unless `--skip-ci`).

Useful flags:
- `--dry-run`
- `--skip-ci`
- `--project ai-nutrition-assistant-e2346`
