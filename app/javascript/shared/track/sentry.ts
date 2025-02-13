import * as Sentry from '@sentry/browser';
import { getConfig } from '@utils';

const {
  sentry: { key, enabled, user, environment, browser, release }
} = getConfig();

// We need to check for key presence here as we do not have a dsn for browser yet
if (enabled && key) {
  Sentry.init({
    dsn: key,
    release: release ?? undefined,
    environment,
    tracesSampleRate: 0.1,
    ignoreErrors: [
      // Ignore errors generated by a Microsoft crawler.
      // See https://forum.sentry.io/t/unhandledrejection-non-error-promise-rejection-captured-with-value/14062
      'Non-error promise rejection captured with keys',
      'Non-Error promise rejection captured with value',

      // Error with password input with a password manager, pending a DSFR fix
      'e.getModifierState is not a function',

      // Piwik/Matomo invasive error
      "'get' on proxy: property 'javaEnabled' is a read-only and non-configurable data property on the proxy target but the proxy did not return its actual value"
    ]
  });

  const scope = Sentry.getCurrentScope();
  scope.setUser(user);
  scope.setExtra('browser', browser.modern ? 'modern' : 'legacy');

  // Register a way to explicitely capture messages from a different bundle.
  addEventListener('sentry:capture-exception', (event) => {
    const error = (event as CustomEvent).detail;
    Sentry.captureException(error);
  });
}
