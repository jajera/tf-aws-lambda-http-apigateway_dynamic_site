const COLORS = [
  { id: 1, name: "Red", hex: "#FF0000" },
  { id: 2, name: "Green", hex: "#00FF00" },
  { id: 3, name: "Blue", hex: "#0000FF" },
  { id: 4, name: "Yellow", hex: "#FFFF00" },
  { id: 5, name: "Cyan", hex: "#00FFFF" },
  { id: 6, name: "Magenta", hex: "#FF00FF" },
  { id: 7, name: "Orange", hex: "#FFA500" },
  { id: 8, name: "Purple", hex: "#800080" },
];

export const handler = async (event) => {
  try {
    console.log(event);

    let result = [];
    let message = "Success";
    let statusCode = 200;

    if (event.routeKey === "GET /colors") {
      result = COLORS;
    } else if (event.routeKey === "GET /colors/{id}") {
      const color = COLORS.find((c) => c.id == event.pathParameters.id);
      if (color) {
        result = color;
      } else {
        message = "Color not found";
        statusCode = 404;
      }
    } else if (event.routeKey === "POST /colors") {
      const newColor = JSON.parse(event.body);

      if (!newColor.id || !newColor.name || !newColor.hex) {
        message = "Invalid input, 'id', 'name', and 'hex' are required";
        statusCode = 400;
      } else if (COLORS.some((c) => c.id === newColor.id)) {
        message = "Color with this ID already exists";
        statusCode = 409;
      } else {
        COLORS.push(newColor);
        result = newColor;
      }
    } else {
      message = "Invalid route";
      statusCode = 400;
    }

    return {
      statusCode: statusCode,
      body: JSON.stringify({
        message: message,
        result: result,
      }),
    };
  } catch (err) {
    console.log(err);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Internal Server Error",
        result: result,
      }),
    };
  }
};
