document.addEventListener('click', async (event) => {
    let clipboard = await waitForElement('[data-clipboard-text]');
    let link = clipboard.getAttribute('data-clipboard-text');

    if (event.target.innerText === 'Generate installer') {
        const element = await waitForElement('#installer-copy-button');
        const cmdBtn =
            '<button id="generate-cmd-command" type="button" style="float:left;margin-right:15px;background-color:#333;color:#eee;border:none;border-radius:4px;padding: 14px 12px;">>_ CMD</button>';
        const psBtn =
            '<button id="generate-ps-command" type="button" style="float:left;margin-right:15px;background-color:#052574;color:#eee;border:none;border-radius:4px;padding: 14px 12px;">>_ PS</button>';

        element.insertAdjacentHTML('beforeBegin', cmdBtn);
        element.insertAdjacentHTML('beforeBegin', psBtn);
    }

    if (event.target.innerText === '>_ CMD') {
        console.log('Generating cmd command');
        command = `msiexec /i ${link} /qb`;
    }

    if (event.target.innerText === '>_ PS') {
        console.log('Generating powershell command');
        command = `Start-Process -FilePath "msiexec" -ArgumentList "/i \`"${link}" /qn" -Wait`;
    }

    if (event.target.innerText === '>_ CMD' || event.target.innerText === '>_ PS') {
        try {
            await navigator.clipboard.writeText(command);
        } catch (err) {
            console.log(err);
        }
    }
});

function waitForElement(selector) {
    return new Promise((resolve) => {
        if (document.querySelector(selector)) {
            return resolve(document.querySelector(selector));
        }

        const observer = new MutationObserver((mutations) => {
            if (document.querySelector(selector)) {
                observer.disconnect();
                resolve(document.querySelector(selector));
            }
        });

        observer.observe(document.body, { childList: true, subtree: true });
    });
}
