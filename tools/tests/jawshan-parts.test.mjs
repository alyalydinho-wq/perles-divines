import assert from 'node:assert/strict';
import test from 'node:test';
import {checkJawshanParts} from '../jawshan-parts.mjs';

test('Jawshan a 100 parties alignées et 100 titres français', async () => {
  const failures = await checkJawshanParts();
  assert.deepEqual(failures, []);
});
