export interface Scenario {
  name: string;
  run(ctx: { post: (body: object) => Promise<Response> }): Promise<void>;
}
