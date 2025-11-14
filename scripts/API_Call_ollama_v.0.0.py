###
# Created on Thu Mar 27 13:30:00 2025
# @author: Alex Rodriguez
###

import requests
import json

# API endpoint to POST
url = "http://localhost:11434/api/chat"

# Static parts of the payload
user = ""
model = "llama3.2"
system_message = "You are my personal assistant."
max_completion_tokens = 80000

# Header for the POST request
headers = {"Content-Type": "application/json"}

print("Welcome to the oLlama chat session. Type 'exit' to quit.")

# Initialize conversation history
conversation_history = []

while True:
    # Get user prompt
    prompt_text = input("Enter your prompt: ")
    if prompt_text.lower() == "exit":
        print("Exiting the session. Goodbye!")
        break
    
    # Add user message to the conversation
    conversation_history.append({
        "role": "user",
        "content": prompt_text
    })
    
    # Prepare the data payload
    data = {
        "model": model,
        "messages": conversation_history,
        "stream": False,
        "options": {
            "num_predict": max_completion_tokens
        }
    }
    
    # Convert the dict to JSON
    payload = json.dumps(data)
    
    try:
        # SEND POST request
        response = requests.post(url, data=payload, headers=headers)
        
        # Try to parse the JSON response and print only the 'response' field
        try:
            json_response = response.json()
            # Get the assistant's message
            assistant_message = json_response.get('message', {})
            assistant_content = assistant_message.get('content', 'No response')
            
            print(f"\nAssistant: {assistant_content}\n")
            
            # Add assistant response to conversation history
            conversation_history.append(assistant_message)
            
        except Exception as json_err:
            print("Error parsing JSON response:", json_err)
            print("Raw response text:", response.text)
    except Exception as req_err:
        print("An error occurred during the request:", req_err)
