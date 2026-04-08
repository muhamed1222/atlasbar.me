const THEME_STORAGE_KEY = "limitbar-promo-theme";
const LANGUAGE_STORAGE_KEY = "limitbar-promo-language";

const COPY = {
  en: {
    htmlLang: "en",
    title: "Limit Bar",
    metaDescription:
      "A quiet macOS menu bar app for keeping an eye on your Codex and Claude usage.",
    ogTitle: "Limit Bar",
    ogDescription:
      "Track sessions, weekly limits, renewals, and account context without opening dashboards all day.",
    titlePrimary: "Limit Bar,",
    titleSecondary: "menu bar app",
    copyLeadStart: "A",
    copyAccent: "quiet",
    copyLeadMiddle: "macOS menu bar app for keeping an eye on your",
    copyLeadEnd: "usage.",
    copyMuted:
      "Track sessions, weekly limits, renewals, and account context without opening dashboards all day.",
    downloadCta: "Download for macOS",
    feedbackCta: "Rate & Review",
    feedbackTitle: "Leave a quick review",
    feedbackReviewLabel: "Review",
    feedbackReviewPlaceholder: "What feels useful, missing, or confusing?",
    feedbackSubmit: "Send review",
    feedbackSuccessTitle: "Review received",
    feedbackSuccessCopy: "Thanks for taking a minute.",
    themeToggleLabel: "Toggle color theme",
    languageSwitcherLabel: "Language switcher",
    feedbackCloseLabel: "Close feedback form",
  },
  ru: {
    htmlLang: "ru",
    title: "Limit Bar",
    metaDescription:
      "Тихое приложение для строки меню macOS, чтобы следить за использованием Codex и Claude.",
    ogTitle: "Limit Bar",
    ogDescription:
      "Следите за сессиями, недельными лимитами, обновлениями и аккаунтами без постоянного открытия дашбордов.",
    titlePrimary: "Limit Bar,",
    titleSecondary: "приложение в строке меню",
    copyLeadStart: "",
    copyAccent: "тихое",
    copyLeadMiddle:
      "приложение для строки меню macOS, чтобы следить за использованием",
    copyLeadEnd: ".",
    copyMuted:
      "Следите за сессиями, недельными лимитами, обновлениями и аккаунтами без постоянного открытия дашбордов.",
    downloadCta: "Скачать для macOS",
    feedbackCta: "Оценить и оставить отзыв",
    feedbackTitle: "Оставьте короткий отзыв",
    feedbackReviewLabel: "Отзыв",
    feedbackReviewPlaceholder: "Что оказалось полезным, чего не хватает или что смущает?",
    feedbackSubmit: "Отправить отзыв",
    feedbackSuccessTitle: "Отзыв получен",
    feedbackSuccessCopy: "Спасибо, что уделили минуту.",
    themeToggleLabel: "Переключить тему",
    languageSwitcherLabel: "Переключатель языка",
    feedbackCloseLabel: "Закрыть форму отзыва",
  },
};

function getPreferredTheme() {
  const stored = window.localStorage.getItem(THEME_STORAGE_KEY);

  if (stored === "light" || stored === "dark") {
    return stored;
  }

  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

function getPreferredLanguage() {
  const stored = window.localStorage.getItem(LANGUAGE_STORAGE_KEY);

  if (stored === "en" || stored === "ru") {
    return stored;
  }

  const browserLanguage = (window.navigator.language || "en").toLowerCase();
  return browserLanguage.startsWith("ru") ? "ru" : "en";
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
}

function toggleTheme() {
  const current = document.documentElement.dataset.theme === "dark" ? "dark" : "light";
  const next = current === "dark" ? "light" : "dark";

  applyTheme(next);
  window.localStorage.setItem(THEME_STORAGE_KEY, next);
}

function applyLanguage(language) {
  const nextLanguage = COPY[language] ? language : "en";
  const dictionary = COPY[nextLanguage];

  document.documentElement.lang = dictionary.htmlLang;
  document.title = dictionary.title;

  document.querySelectorAll("[data-i18n]").forEach((node) => {
    const key = node.dataset.i18n;

    if (key && key in dictionary) {
      node.textContent = dictionary[key];
    }
  });

  document.querySelectorAll("[data-i18n-content]").forEach((node) => {
    const key = node.dataset.i18nContent;

    if (key && key in dictionary) {
      node.setAttribute("content", dictionary[key]);
    }
  });

  document.querySelectorAll("[data-i18n-aria-label]").forEach((node) => {
    const key = node.dataset.i18nAriaLabel;

    if (key && key in dictionary) {
      node.setAttribute("aria-label", dictionary[key]);
    }
  });

  document.querySelectorAll("[data-i18n-placeholder]").forEach((node) => {
    const key = node.dataset.i18nPlaceholder;

    if (key && key in dictionary) {
      node.setAttribute("placeholder", dictionary[key]);
    }
  });

  document.querySelectorAll("[data-language-option]").forEach((button) => {
    const isActive = button.dataset.languageOption === nextLanguage;
    button.setAttribute("aria-pressed", String(isActive));
  });

  window.localStorage.setItem(LANGUAGE_STORAGE_KEY, nextLanguage);
}

function encodeFormData(formData) {
  return new URLSearchParams(Array.from(formData.entries())).toString();
}

function setFeedbackRating(value) {
  const ratingValue = String(value);
  const ratingInput = document.querySelector("[data-feedback-rating-input]");

  if (ratingInput) {
    ratingInput.value = ratingValue;
  }

  document.querySelectorAll(".feedback-star").forEach((star) => {
    const starValue = Number(star.dataset.ratingValue || "0");
    const isActive = starValue <= Number(ratingValue);
    star.classList.toggle("is-active", isActive);
    star.setAttribute("aria-pressed", String(isActive));
  });
}

function resetFeedbackFormUI() {
  const modal = document.querySelector("[data-feedback-modal]");
  const form = document.querySelector("[data-feedback-form]");
  const formContent = document.querySelector("[data-feedback-form-content]");
  const successState = document.querySelector("[data-feedback-success]");

  form?.reset();
  setFeedbackRating(0);
  formContent?.removeAttribute("hidden");
  successState?.setAttribute("hidden", "");

  if (modal?.hidden === false) {
    form?.querySelector(".feedback-form__textarea")?.focus();
  }
}

function openFeedbackModal() {
  const modal = document.querySelector("[data-feedback-modal]");

  if (!modal) {
    return;
  }

  modal.hidden = false;
  document.body.classList.add("is-feedback-open");
  window.requestAnimationFrame(resetFeedbackFormUI);
}

function closeFeedbackModal() {
  const modal = document.querySelector("[data-feedback-modal]");

  if (!modal) {
    return;
  }

  modal.hidden = true;
  document.body.classList.remove("is-feedback-open");
}

document.addEventListener("DOMContentLoaded", () => {
  try {
    applyTheme(getPreferredTheme());
  } catch {
    applyTheme("light");
  }

  try {
    applyLanguage(getPreferredLanguage());
  } catch {
    applyLanguage("en");
  }

  const themeToggle = document.querySelector("[data-theme-toggle]");

  if (themeToggle) {
    themeToggle.addEventListener("click", toggleTheme);
  }

  document.querySelectorAll("[data-language-option]").forEach((button) => {
    button.addEventListener("click", () => {
      applyLanguage(button.dataset.languageOption || "en");
    });
  });

  document.querySelector("[data-feedback-open]")?.addEventListener("click", openFeedbackModal);

  document.querySelectorAll("[data-feedback-close]").forEach((button) => {
    button.addEventListener("click", closeFeedbackModal);
  });

  document.querySelectorAll(".feedback-star").forEach((star) => {
    star.setAttribute("aria-pressed", "false");
    star.addEventListener("click", () => {
      setFeedbackRating(star.dataset.ratingValue || "0");
    });
  });

  setFeedbackRating(0);

  const feedbackForm = document.querySelector("[data-feedback-form]");

  feedbackForm?.addEventListener("submit", async (event) => {
    event.preventDefault();

    const form = event.currentTarget;

    if (!(form instanceof HTMLFormElement)) {
      return;
    }

    const formData = new FormData(form);

    try {
      await fetch("/", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: encodeFormData(formData),
      });

      form.querySelector("[data-feedback-form-content]")?.setAttribute("hidden", "");
      form.querySelector("[data-feedback-success]")?.removeAttribute("hidden");
    } catch {
      // Keep failure quiet for now and let the user retry without extra UI noise.
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeFeedbackModal();
    }
  });

  window.requestAnimationFrame(() => {
    document.body.classList.add("is-ready");
  });
});
