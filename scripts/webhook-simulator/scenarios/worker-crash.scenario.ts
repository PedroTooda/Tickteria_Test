import { Scenario } from '../scenario.contract';

export const scenario: Scenario = {
  name: 'worker-crash',
  async run() {
    throw new Error('cenário worker-crash não implementado');
  },
};
