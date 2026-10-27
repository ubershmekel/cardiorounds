# Cardio rounds

An open source heart rate monitoring app. With charts, zones, and analysis
designed for treadmill running, interval training and BJJ rounds.

## Download

- **Android:**
  [Get it on Google Play](https://play.google.com/store/apps/details?id=com.andluck.cardio)
- **iOS:**
  [Download on the App Store](https://apps.apple.com/us/app/cardio-rounds/id6777868430)
- [Try the web app (fake heart rate data only)](https://ubershmekel.github.io/cardiorounds/try/)

## Features

- Local data storage, no sign-in, no ads, all private
- Simple, easy to use UI
- Beautiful charts
- Start a workout, stop a workout, and record your recovery.
- Enter your resting heart rate, and max heart rate for zone calculations
- See your max heart rate, zones chart, how much time you spent in each zone
- See your rate of recovery
- Compare your historical stats
- Export your data for backup or analysis
- Open source, no lock in, no subscription

## Development

Install the shared Git hooks once per clone:

```sh
task hooks-install
```

The pre-commit hook runs `task format-check` and fails when files need
formatting. Run `task format` to apply formatter changes.
