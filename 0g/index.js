import OpenAI from 'openai'

async function mockGraphqlQuery() {
  const hasData = Math.random() > 0.5;

  if (!hasData) {
    return null;
  }

  return {
    id: crypto.randomUUID(),
    type: "NEW_FILE_UPLOADED",
    source: "mock-graphql",
    fileId: "walrus-file-123",
    timestamp: new Date().toISOString()
  };
}

function main() {
    const client = new OpenAI({
      baseURL: `${process.env.ZG_SERVICE_URL}/v1/proxy`,
      apiKey: process.env.ZG_API_SECRET,    // the app-sk-... from step 03
    })

    const txs = mockGraphqlQuery()

    const prompt = `\
    Act as an AML agent, scan this batch of transaction and check if there is a potential fraud.\
    The transactions starts from here:\
    ${JSON.stringify(txs)} 
    `
    
    const completion = await client.chat.completions.create({
      model: 'qwen/qwen-2.5-7b-instruct',     // or any model listed on pc.0g.ai
      messages: [{ role: 'user', content: prompt }],
    })
    
    console.log(completion.choices[0].message.content)
}


main()