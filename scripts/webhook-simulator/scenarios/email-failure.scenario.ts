import { Scenario } from '../scenario.contract';

export const scenario: Scenario = {
  name: 'email-failure',
  async run() {
    throw new Error('cenário email-failure não implementado');
  },
};
