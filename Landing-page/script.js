document.addEventListener('DOMContentLoaded', () => {
    // 1. Mobile Menu Toggle
    const menuToggle = document.getElementById('menu-toggle');
    const closeToggle = document.getElementById('close-toggle');
    const mobileNav = document.getElementById('mobile-nav');
    const mobileLinks = document.querySelectorAll('.mobile-nav-list a');

    const toggleMenu = (active) => {
        mobileNav.classList.toggle('active', active);
        document.body.style.overflow = active ? 'hidden' : '';
    };

    menuToggle.addEventListener('click', () => toggleMenu(true));
    closeToggle.addEventListener('click', () => toggleMenu(false));
    mobileLinks.forEach(link => link.addEventListener('click', () => toggleMenu(false)));

    // 2. Sticky Header Effect
    const header = document.getElementById('header');
    window.addEventListener('scroll', () => {
        if (window.scrollY > 50) {
            header.classList.add('scrolled');
        } else {
            header.classList.remove('scrolled');
        }
    });

    // 3. Counter Animation for Stats
    const stats = document.querySelectorAll('.stat-value[data-target]');
    const countObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const target = parseInt(entry.target.getAttribute('data-target'));
                animateValue(entry.target, 0, target, 2000);
                countObserver.unobserve(entry.target);
            }
        });
    }, { threshold: 0.1 });

    function animateValue(obj, start, end, duration) {
        let startTimestamp = null;
        const step = (timestamp) => {
            if (!startTimestamp) startTimestamp = timestamp;
            const progress = Math.min((timestamp - startTimestamp) / duration, 1);
            obj.innerHTML = Math.floor(progress * (end - start) + start).toLocaleString() + (end === 100 ? '' : '+');
            if (progress < 1) {
                window.requestAnimationFrame(step);
            }
        };
        window.requestAnimationFrame(step);
    }

    stats.forEach(stat => countObserver.observe(stat));

    // 4. Feature Showcase Tabs
    const featBtns = document.querySelectorAll('.feat-btn');
    const featPanes = document.querySelectorAll('.feat-pane');

    featBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const target = btn.getAttribute('data-target');

            // Update buttons
            featBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            // Update panes
            featPanes.forEach(pane => {
                pane.classList.remove('active');
                if (pane.id === target) {
                    pane.classList.add('active');
                }
            });
        });
    });

    // 5. Reveal Animations
    const revealElements = document.querySelectorAll('.reveal');
    const revealObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('active');
            }
        });
    }, { threshold: 0.1, rootMargin: '0px 0px -50px 0px' });

    revealElements.forEach(el => revealObserver.observe(el));

    // 6. Smooth Scroll for Nav Links
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            const href = this.getAttribute('href');
            if (href === '#') return;

            e.preventDefault();
            const target = document.querySelector(href);
            if (target) {
                window.scrollTo({
                    top: target.offsetTop - 80,
                    behavior: 'smooth'
                });
            }
        });
    });

    // 7. Image Preview Modal
    const modal = document.getElementById('image-modal');
    const modalImg = document.getElementById('modal-img');
    const captionText = document.getElementById('modal-caption');
    const previewTriggers = document.querySelectorAll('.preview-trigger');
    const closeBtn = document.getElementsByClassName('modal-close')[0];

    previewTriggers.forEach(trigger => {
        trigger.onclick = function () {
            modal.style.display = "flex";
            modalImg.src = this.getAttribute('data-img');
            captionText.innerHTML = this.querySelector('.proof-caption').innerHTML;
            document.body.style.overflow = 'hidden';
        }
    });

    closeBtn.onclick = function () {
        modal.style.display = "none";
        document.body.style.overflow = '';
    }

    window.onclick = function (event) {
        if (event.target == modal) {
            modal.style.display = "none";
            document.body.style.overflow = '';
        }
    }
});
