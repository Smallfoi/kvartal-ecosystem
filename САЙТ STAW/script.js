const header = document.querySelector("[data-header]");
const filters = document.querySelectorAll("[data-filter]");
const productCards = document.querySelectorAll("[data-category]");
const cartPanel = document.querySelector("[data-cart-panel]");
const overlay = document.querySelector("[data-overlay]");
const cartToggles = document.querySelectorAll("[data-cart-toggle]");
const cartItems = document.querySelector("[data-cart-items]");
const cartCount = document.querySelector("[data-cart-count]");
const cartTotal = document.querySelector("[data-cart-total]");
const addButtons = document.querySelectorAll("[data-add-cart]");
const revealItems = document.querySelectorAll(".reveal");

const cart = [];

function updateHeader() {
  header.classList.toggle("is-scrolled", window.scrollY > 24);
}

function applyFilter(category) {
  filters.forEach((button) => {
    button.classList.toggle("is-active", button.dataset.filter === category);
  });

  productCards.forEach((card) => {
    const shouldShow = category === "all" || card.dataset.category === category;
    card.classList.toggle("is-hidden", !shouldShow);
  });
}

function toggleCart() {
  cartPanel.classList.toggle("is-open");
  overlay.classList.toggle("is-open");
}

function formatPrice(value) {
  return new Intl.NumberFormat("ru-RU").format(value) + " ₽";
}

function renderCart() {
  cartCount.textContent = cart.length;

  if (cart.length === 0) {
    cartItems.innerHTML = '<p class="empty-cart">Корзина пуста</p>';
    cartTotal.textContent = "0 ₽";
    return;
  }

  const total = cart.reduce((sum, item) => sum + item.price, 0);

  cartItems.innerHTML = cart
    .map(
      (item) => `
        <div class="cart-item">
          <p>${item.name}</p>
          <span>${formatPrice(item.price)}</span>
        </div>
      `,
    )
    .join("");

  cartTotal.textContent = formatPrice(total);
}

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  {
    rootMargin: "0px 0px -12% 0px",
    threshold: 0.18,
  },
);

revealItems.forEach((item, index) => {
  item.style.setProperty("--delay", `${Math.min(index % 4, 3) * 90}ms`);
  revealObserver.observe(item);
});

filters.forEach((button) => {
  button.addEventListener("click", () => applyFilter(button.dataset.filter));
});

cartToggles.forEach((button) => {
  button.addEventListener("click", toggleCart);
});

addButtons.forEach((button) => {
  button.addEventListener("click", () => {
    cart.push({
      name: button.dataset.addCart,
      price: Number(button.dataset.price),
    });
    renderCart();

    if (!cartPanel.classList.contains("is-open")) {
      toggleCart();
    }
  });
});

window.addEventListener("scroll", updateHeader, { passive: true });
updateHeader();
renderCart();
