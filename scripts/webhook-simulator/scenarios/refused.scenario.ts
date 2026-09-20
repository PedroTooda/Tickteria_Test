import { Scenario } from '../scenario.contract';

export const scenario: Scenario = {
  name: 'refused',
  async run() {
    throw new Error('cenário refused não implementado');
  },
};
