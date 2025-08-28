# app.py
from flask import Flask, request, jsonify
from calculator_logic import add, subtract, multiply, divide

app = Flask(__name__)

@app.route("/add")
def add_route():
    a = int(request.args.get("a"))
    b = int(request.args.get("b"))
    return jsonify(result=add(a, b))

@app.route("/subtract")
def subtract_route():
    a = int(request.args.get("a"))
    b = int(request.args.get("b"))
    return jsonify(result=subtract(a, b))

@app.route("/multiply")
def multiply_route():
    a = int(request.args.get("a"))
    b = int(request.args.get("b"))
    return jsonify(result=multiply(a, b))

@app.route("/divide")
def divide_route():
    a = int(request.args.get("a"))
    b = int(request.args.get("b"))
    return jsonify(result=divide(a, b))

@app.route("/health")
def health():
    return jsonify(status="ok")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

