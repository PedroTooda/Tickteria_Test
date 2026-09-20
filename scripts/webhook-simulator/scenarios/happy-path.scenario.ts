import { Scenario } from '../scenario.contract';

export const scenario: Scenario = {
  name: 'happy-path',
  async run() {
    throw new Error('cenário happy-path não implementado');
  },
};
