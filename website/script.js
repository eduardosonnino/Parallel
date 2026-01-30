/**
 * Parallel Website
 * Minimal JavaScript for waitlist functionality
 */

document.addEventListener('DOMContentLoaded', () => {
    initWaitlistForm();
    initSmoothScroll();
    initNavScroll();
    animateOnScroll();
});

/**
 * Waitlist Form Handling
 */
function initWaitlistForm() {
    const form = document.getElementById('waitlist-form');
    const success = document.getElementById('waitlist-success');
    const countEl = document.getElementById('waitlist-count');

    if (!form) return;

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const email = form.querySelector('input[type="email"]').value;
        const button = form.querySelector('button');

        // Disable button and show loading state
        button.disabled = true;
        button.innerHTML = '<span>Joining...</span>';

        // Simulate API call (replace with actual endpoint)
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Store in localStorage for demo (replace with actual API)
        const waitlist = JSON.parse(localStorage.getItem('parallel_waitlist') || '[]');
        if (!waitlist.includes(email)) {
            waitlist.push(email);
            localStorage.setItem('parallel_waitlist', JSON.stringify(waitlist));
        }

        // Show success state
        form.classList.add('hidden');
        success.classList.add('show');

        // Update count
        if (countEl) {
            const currentCount = parseInt(countEl.textContent.replace(/,/g, ''));
            countEl.textContent = (currentCount + 1).toLocaleString();
        }
    });
}

/**
 * Smooth Scroll for Anchor Links
 */
function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', (e) => {
            e.preventDefault();
            const target = document.querySelector(anchor.getAttribute('href'));
            if (target) {
                const navHeight = document.querySelector('.nav').offsetHeight;
                const targetPosition = target.getBoundingClientRect().top + window.pageYOffset - navHeight;

                window.scrollTo({
                    top: targetPosition,
                    behavior: 'smooth'
                });
            }
        });
    });
}

/**
 * Navigation Background on Scroll
 */
function initNavScroll() {
    const nav = document.querySelector('.nav');
    let lastScroll = 0;

    window.addEventListener('scroll', () => {
        const currentScroll = window.pageYOffset;

        if (currentScroll > 50) {
            nav.style.background = 'rgba(10, 10, 10, 0.95)';
        } else {
            nav.style.background = 'rgba(10, 10, 10, 0.8)';
        }

        lastScroll = currentScroll;
    });
}

/**
 * Animate Elements on Scroll
 */
function animateOnScroll() {
    const observerOptions = {
        root: null,
        rootMargin: '0px',
        threshold: 0.1
    };

    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-in');
                observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    // Observe feature cards
    document.querySelectorAll('.feature-card').forEach((card, index) => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        card.style.transition = `all 0.5s ease ${index * 0.1}s`;
        observer.observe(card);
    });

    // Observe steps
    document.querySelectorAll('.step').forEach((step, index) => {
        step.style.opacity = '0';
        step.style.transform = 'translateY(20px)';
        step.style.transition = `all 0.5s ease ${index * 0.15}s`;
        observer.observe(step);
    });
}

// Add animate-in class styles
const style = document.createElement('style');
style.textContent = `
    .animate-in {
        opacity: 1 !important;
        transform: translateY(0) !important;
    }
`;
document.head.appendChild(style);

/**
 * Terminal Animation (optional enhancement)
 */
function animateTerminal() {
    const times = document.querySelectorAll('.instance-time');

    setInterval(() => {
        times.forEach(time => {
            const [mins, secs] = time.textContent.split(/[ms ]/).filter(Boolean).map(Number);
            let totalSecs = mins * 60 + secs + 1;
            const newMins = Math.floor(totalSecs / 60);
            const newSecs = totalSecs % 60;
            time.textContent = `${newMins}m ${String(newSecs).padStart(2, '0')}s`;
        });
    }, 1000);
}

// Start terminal animation after page load
setTimeout(animateTerminal, 1000);
