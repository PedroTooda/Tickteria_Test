import { Scenario } from '../scenario.contract';

export const scenario: Scenario = {
  name: 'redis-down',
  async run() {
    throw new Error('cenário redis-down não implementado');
  },
};
