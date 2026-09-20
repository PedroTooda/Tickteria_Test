import { Scenario } from '../scenario.contract';

export const scenario: Scenario = {
  name: 'unknown-order',
  async run() {
    throw new Error('cenário unknown-order não implementado');
  },
};
