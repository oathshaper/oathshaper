// Uses an installed Playwright; does not install dependencies or touch game saves.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const assert = require('node:assert/strict');
const catalog = require('../godot/content/rpg_catalog.json');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(pathToFileURL(path.resolve(__dirname, '../docs/design/combat-profile-preview.html')).href);
  let states = 0;
  for (const [id, profile] of Object.entries(catalog.profiles)) {
    await page.locator(`[data-profile="${id}"]`).click();
    await page.locator('#inspect').click();
    const roles = new Set();
    for (const actor of catalog.actors) {
      const build = profile.builds[actor.id];
      await page.locator(`[data-actor="${actor.id}"]`).click();
      assert.equal(await page.locator('#actor-role').textContent(), build.role);
      roles.add(build.role);
      for (const tab of ['Character', 'Equipment', 'Abilities', 'Inventory']) {
        await page.locator(`[data-page="${tab}"]`).click();
        const copy = await page.locator('#page-content').textContent();
        const expected = { Character: build.loop, Equipment: build.gear[0].name, Abilities: build.abilities[0].source, Inventory: profile.inventory }[tab];
        assert.ok(copy.includes(expected), `${id}/${actor.id}/${tab}: actor content missing`);
        assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth), false, 'horizontal overflow');
        states++;
      }
    }
    assert.equal(roles.size, 4, `${id}: repeated generic role`);
    await page.locator('[data-page="Saves"]').click();
    await page.locator('#bookmark').click();
    await page.locator('[data-actor="player"]').click();
    await page.locator('#restore').click();
    assert.equal(await page.locator('[data-actor="clerk"]').getAttribute('aria-pressed'), 'true');
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('#main-menu').isVisible(), true);
  }
  await page.locator('[data-profile="vanguard"]').click();
  await page.locator('#inspect').click();
  await page.locator('[data-actor="mara"]').click();
  await page.locator('[data-page="Equipment"]').click();
  await page.screenshot({ path: path.resolve(__dirname, '../docs/images/combat-archetype-study-1280x800.png') });
  assert.deepEqual(errors, []);
  await browser.close();
  console.log(`PARTY_PREVIEW_OK: ${states} actor/page states, 9 bookmark/back flows, no script errors`);
})().catch(error => { console.error(error); process.exit(1); });
