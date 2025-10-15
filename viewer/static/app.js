document.addEventListener('DOMContentLoaded', () => {
    const sidebar = document.getElementById('article-list');
    const content = document.getElementById('content');

    // --- Functions ---

    /**
     * Fetches the list of articles from the API and populates the sidebar.
     */
    async function loadArticleList() {
        try {
            const response = await fetch('/api/articles');
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            const articles = await response.json();

            sidebar.innerHTML = ''; // Clear any existing content
            articles.forEach(article => {
                const li = document.createElement('li');
                const a = document.createElement('a');
                a.href = `#${article.slug}`;
                a.textContent = article.title;
                a.dataset.slug = article.slug; // Store slug for easy access

                a.addEventListener('click', (event) => {
                    event.preventDefault();
                    window.location.hash = article.slug;
                    loadArticleContent(article.slug);
                });

                li.appendChild(a);
                sidebar.appendChild(li);
            });
        } catch (error) {
            sidebar.innerHTML = '<li>Failed to load articles.</li>';
            console.error('Error fetching article list:', error);
        }
    }

    /**
     * Fetches and renders the Markdown content for a specific article.
     * @param {string} slug - The slug of the article to load.
     */
    async function loadArticleContent(slug) {
        if (!slug) {
            content.innerHTML = '<p>Select an article from the sidebar to begin reading.</p>';
            return;
        }

        try {
            content.innerHTML = '<p>Loading...</p>';
            const response = await fetch(`/api/articles/${slug}`);
            if (!response.ok) {
                throw new Error(`HTTP error! Status: ${response.status}`);
            }
            const markdown = await response.text();

            // The Rendering Pipeline
            // 1. Convert Markdown to HTML
            marked.use(markedBaseUrl.baseUrl(`/articles/${slug}/`));
            content.innerHTML = marked.parse(markdown);

            // 2. Apply syntax highlighting to the new content
            hljs.highlightAll();

            // 3. Re-render any LaTeX equations in the new content
            MathJax.typeset();

        } catch (error) {
            content.innerHTML = `<p>Error loading article: ${error.message}</p>`;
            console.error(`Error fetching article "${slug}":`, error);
        }
    }

    // --- Initial Load ---

    // Load the article list when the page is first loaded.
    loadArticleList();

    // Check if there's an article slug in the URL hash on load.
    const initialSlug = window.location.hash.substring(1);
    if (initialSlug) {
        loadArticleContent(initialSlug);
    }
});