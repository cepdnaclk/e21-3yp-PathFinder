(function () {
  "use strict";

  document.documentElement.classList.add("js-enabled");

  var prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var header = document.querySelector("[data-header]");
  var navToggle = document.querySelector(".nav-toggle");
  var navMenu = document.getElementById("nav-menu");
  var navLinks = Array.prototype.slice.call(document.querySelectorAll(".nav-link"));
  var backToTop = document.querySelector(".back-to-top");
  var currentYear = document.getElementById("current-year");
  var lightbox = document.querySelector(".lightbox");
  var lightboxImage = document.querySelector(".lightbox-image");
  var lightboxCaption = document.getElementById("lightbox-caption");
  var lightboxClose = document.querySelector(".lightbox-close");
  var lastFocusedElement = null;

  function setMenuState(isOpen) {
    if (!navToggle || !navMenu) {
      return;
    }

    navToggle.setAttribute("aria-expanded", String(isOpen));
    navToggle.setAttribute("aria-label", isOpen ? "Close navigation menu" : "Open navigation menu");
    navMenu.classList.toggle("is-open", isOpen);
  }

  function closeMenu() {
    setMenuState(false);
  }

  if (navToggle && navMenu) {
    navToggle.addEventListener("click", function () {
      var isOpen = navToggle.getAttribute("aria-expanded") === "true";
      setMenuState(!isOpen);
    });

    navLinks.forEach(function (link) {
      link.addEventListener("click", closeMenu);
    });

    document.addEventListener("click", function (event) {
      var clickedInsideMenu = navMenu.contains(event.target);
      var clickedToggle = navToggle.contains(event.target);

      if (!clickedInsideMenu && !clickedToggle) {
        closeMenu();
      }
    });

    window.addEventListener("resize", function () {
      if (window.innerWidth >= 900) {
        closeMenu();
      }
    });
  }

  function updateScrollState() {
    var scrolled = window.scrollY > 16;

    if (header) {
      header.classList.toggle("is-scrolled", scrolled);
    }

    if (backToTop) {
      backToTop.classList.toggle("is-visible", window.scrollY > 520);
    }
  }

  updateScrollState();
  window.addEventListener("scroll", updateScrollState, { passive: true });

  if (currentYear) {
    currentYear.textContent = String(new Date().getFullYear());
  }

  if (backToTop) {
    backToTop.addEventListener("click", function () {
      window.scrollTo({
        top: 0,
        behavior: prefersReducedMotion ? "auto" : "smooth"
      });
    });
  }

  function setActiveLink(sectionId) {
    navLinks.forEach(function (link) {
      var isActive = link.getAttribute("href") === "#" + sectionId;
      link.classList.toggle("is-active", isActive);

      if (isActive) {
        link.setAttribute("aria-current", "page");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  }

  if ("IntersectionObserver" in window && navLinks.length > 0) {
    var observedSections = navLinks
      .map(function (link) {
        var href = link.getAttribute("href");
        return href && href.charAt(0) === "#" ? document.querySelector(href) : null;
      })
      .filter(Boolean);

    var activeObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          setActiveLink(entry.target.id);
        }
      });
    }, {
      rootMargin: "-35% 0px -55% 0px",
      threshold: 0.01
    });

    observedSections.forEach(function (section) {
      activeObserver.observe(section);
    });
  }

  var revealItems = Array.prototype.slice.call(document.querySelectorAll(".reveal"));

  if (prefersReducedMotion || !("IntersectionObserver" in window)) {
    revealItems.forEach(function (item) {
      item.classList.add("is-visible");
    });
  } else {
    var revealObserver = new IntersectionObserver(function (entries, observer) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    }, {
      threshold: 0.12
    });

    revealItems.forEach(function (item) {
      revealObserver.observe(item);
    });
  }

  function openLightbox(trigger) {
    if (!lightbox || !lightboxImage || !lightboxCaption) {
      return;
    }

    var fullImage = trigger.getAttribute("data-full");
    var caption = trigger.getAttribute("data-caption") || "";
    var image = trigger.querySelector("img");

    if (!fullImage) {
      return;
    }

    lastFocusedElement = document.activeElement;
    lightboxImage.src = fullImage;
    lightboxImage.alt = image ? image.alt : caption;
    lightboxCaption.textContent = caption;
    lightbox.hidden = false;
    document.body.classList.add("no-scroll");

    if (lightboxClose) {
      lightboxClose.focus();
    }
  }

  function closeLightbox() {
    if (!lightbox) {
      return;
    }

    lightbox.hidden = true;
    document.body.classList.remove("no-scroll");

    if (lastFocusedElement && typeof lastFocusedElement.focus === "function") {
      lastFocusedElement.focus();
    }
  }

  Array.prototype.slice.call(document.querySelectorAll(".gallery-card")).forEach(function (button) {
    button.addEventListener("click", function () {
      openLightbox(button);
    });
  });

  if (lightboxClose) {
    lightboxClose.addEventListener("click", closeLightbox);
  }

  if (lightbox) {
    lightbox.addEventListener("click", function (event) {
      if (event.target === lightbox) {
        closeLightbox();
      }
    });
  }

  document.addEventListener("keydown", function (event) {
    if (event.key === "Tab" && lightbox && !lightbox.hidden) {
      var focusable = Array.prototype.slice.call(lightbox.querySelectorAll("button, [href], input, select, textarea, [tabindex]:not([tabindex='-1'])"));

      if (focusable.length > 0) {
        var first = focusable[0];
        var last = focusable[focusable.length - 1];

        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    }

    if (event.key === "Escape") {
      closeMenu();

      if (lightbox && !lightbox.hidden) {
        closeLightbox();
      }
    }
  });

  Array.prototype.slice.call(document.querySelectorAll(".placeholder-link")).forEach(function (link) {
    link.addEventListener("click", function (event) {
      event.preventDefault();
    });
  });
})();
