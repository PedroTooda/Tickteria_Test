import { Scenario } from '../scenario.contract';

export const scenario: Scenario = {
  name: 'invalid-signature',
  async run() {
    throw new Error('cenário invalid-signature não implementado');
  },
};
