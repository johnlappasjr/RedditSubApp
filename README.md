# RedditSubApp

A macOS SwiftUI app that displays your subscribed subreddits in a custom WebView and allows you to **unsubscribe from them directly** using the old Reddit interface.

## 📦 Features

- Embedded `WKWebView` to access and manipulate [old.reddit.com](https://old.reddit.com)
- Login button to navigate to the Reddit login page
- One-click loading of your subscribed subreddits
- Uses JavaScript injection to:
  - Detect if you're logged in
  - Grab your subreddit list using jQuery
  - Display subreddit names with unsubscribe buttons
  - Send unsubscribe requests directly to Reddit's API

## 🖥️ Screenshots

> _Coming soon!_ Add screenshots of the app UI here.

## 🚀 Getting Started

### Requirements

- macOS 11+
- Xcode 13+
- SwiftUI
- Internet connection and a Reddit account

### Running the App

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/RedditSubApp.git
   cd RedditSubApp
   ```

2. Open the project in Xcode:
   ```bash
   open RedditSubApp.xcodeproj
   ```

3. Build and run the app.

4. Use the **Login** button to sign in to Reddit (opens the old Reddit login page).

5. Click **Load Subreddits** to view and manage your subscriptions.

## ⚠️ Warnings

- This app uses **JavaScript injection** into Reddit's website, which may break if Reddit changes their page structure.
- All unsubscribe actions are done via Reddit's public `/api/subscribe` endpoint.
- Accepts all HTTPS certificates for development purposes. You should **remove or restrict that behavior** before production.
- Requires jQuery to be available on the loaded Reddit page (which is true for old Reddit).

## 🧰 Developer Notes

- `WebViewStore.swift` is a wrapper around `WKWebView` that manages configuration, navigation, and script injection.
- Uses `NSViewRepresentable` to embed `WKWebView` in a SwiftUI view.
- Script checks and injects only on `old.reddit.com`. If the user lands on another domain, it redirects them.

## 📄 License

This project is licensed under the MIT License. See `LICENSE` for details.

## 🙌 Credits

Created by [John Lappas](https://github.com/johnlappas).
