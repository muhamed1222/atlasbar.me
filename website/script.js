const STORAGE_KEY = "limitbar-promo-theme";

function getPreferredTheme() {
  const stored = window.localStorage.getItem(STORAGE_KEY);

  if (stored === "light" || stored === "dark") {
    return stored;
  }

  return window.matchMedia("(prefers-color-scheme: dark)").matches
    ? "dark"
    : "light";
}

function applyTheme(theme) {
  document.documentElement.dataset.theme = theme;
}

function toggleTheme() {
  const current = document.documentElement.dataset.theme === "dark" ? "dark" : "light";
  const next = current === "dark" ? "light" : "dark";

  applyTheme(next);
  window.localStorage.setItem(STORAGE_KEY, next);
}

document.addEventListener("DOMContentLoaded", () => {
  try {
    applyTheme(getPreferredTheme());
  } catch {
    applyTheme("light");
  }

  const toggle = document.querySelector("[data-theme-toggle]");

  if (toggle) {
    toggle.addEventListener("click", toggleTheme);
  }

  window.requestAnimationFrame(() => {
    document.body.classList.add("is-ready");
  });
});
