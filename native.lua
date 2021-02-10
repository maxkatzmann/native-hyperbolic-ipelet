-----------------------------------------------------------------------
-- Pure Lua implementation for the hyperbolic trigonometric functions
-- Freely adapted from P.J.Plauger, "The Standard C Library"
-- author: Roberto Ierusalimschy
-----------------------------------------------------------------------
local exp = math.exp

function cosh (x)
  if x == 0.0 then return 1.0 end
  if x < 0.0 then x = -x end
  x = exp(x)
  x = x / 2.0 + 0.5 / x
  return x
end


function sinh (x)
  if x == 0 then return 0.0 end
  local neg = false
  if x < 0 then x = -x; neg = true end
  if x < 1.0 then
    local y = x * x
    x = x + x * y *
        (((-0.78966127417357099479e0  * y +
           -0.16375798202630751372e3) * y +
           -0.11563521196851768270e5) * y +
           -0.35181283430177117881e6) /
        ((( 0.10000000000000000000e1  * y +
           -0.27773523119650701667e3) * y +
            0.36162723109421836460e5) * y +
           -0.21108770058106271242e7)
  else
    x =  exp(x)
    x = x / 2.0 - 0.5 / x
  end
  if neg then x = -x end
  return x
end


function tanh (x)
  if x == 0 then return 0.0 end
  local neg = false
  if x < 0 then x = -x; neg = true end
  if x < 0.54930614433405 then
    local y = x * x
    x = x + x * y *
        ((-0.96437492777225469787e0  * y +
          -0.99225929672236083313e2) * y +
          -0.16134119023996228053e4) /
        (((0.10000000000000000000e1  * y +
           0.11274474380534949335e3) * y +
           0.22337720718962312926e4) * y +
           0.48402357071988688686e4)
  else
    x = exp(x)
    x = 1.0 - 2.0 / (x * x + 1.0)
  end
  if neg then x = -x end
  return x
end

local abs, log, sqrt = math.abs, math.log, math.sqrt
local log2 = log(2)

-- good for IEEE754, double precision
local function islarge (x) return x > 2 ^ 28 end
local function issmall (x) return x < 2 ^ (-28) end

local INF = math.huge
local function isinfornan (x)
  return x ~= x or x == INF or x == -INF
end

local function log1p (x) -- not very precise, but works well
  local u = 1 + x
  if u == 1 then return x end -- x < eps?
  return log(u) * x / (u - 1)
end

local function acosh (x)
  if x < 1 then return (x - x) / (x - x) end -- nan
  if islarge(x) then
    if isinfornan(x) then return x + x end
    return log2 + log(x)
  end
  if x + 1 == 1 then return 0 end -- acosh(1) == 0
  if x > 2 then
    local x2 = x * x
    return log(2 * x - 1 / (x + sqrt(x2 - 1)))
  end
  -- 1 < x < 2:
  local t = x - 1
  return log1p(t + sqrt(2 * t + t * t))
end

local function asinh (x)
  local y = abs(x)
  if issmall(y) then return x end
  local a
  if islarge(y) then -- very large?
    if isinfornan(x) then return x + x end
    a = log2 + log(y)
  else
    if y > 2 then
      a = log(2 * y + 1 / (y + sqrt(1 + y * y)))
    else
      local y2 = y * y
      a = log1p(y + y2 / (1 + sqrt(1 + y2)))
    end
  end
  return x < 0 and -a or a -- transfer sign
end

local function atanh (x)
  local y = abs(x)
  local a
  if y < .5 then
    if issmall(y) then return x end
    a = 2 * y
    a = .5 * log1p(a + a * y / (1 - y))
  else
    if y < 1 then
      a = .5 * log1p(2 * y / (1 - y))
    elseif y > 1 then
      return (x - x) / (x - x) -- nan
    else -- y == 1
      return x / 0 -- inf with sign
    end
  end
  return x < 0 and -a or a -- transfer sign
end

label = "Native Representation"

about = [[ The native representation of the hyperbolic plane. ]]

-- The 'reference_ray' defines the origin of the plane (which is the
-- origin of the ray) as well as the direction that is associated with
-- the x-axis.  This means that the x-axis is identified with the line
-- through origin and target.  Furthermore, we assume that the
-- hyperbolic distance between origin and target is 'reference_scale'
-- (see below).
local reference_ray = { origin = ipe.Vector(64, 64), target = ipe.Vector(128, 64) }

-- We assume that the difference between the origin and the reference
-- target to be 'reference_scale'.
local reference_scale = 16

----------------------------------------------------------------------
-- overwriting the original function
----------------------------------------------------------------------
function _G.MODEL:native_backup_startModeTool (modifiers) end
_G.MODEL.native_backup_startModeTool = _G.MODEL.startModeTool

function _G.MODEL:startModeTool(modifiers)
   if self.mode == "native_line_segment" then
      NATIVE_LINETOOL:new(self, self.mode)
   elseif self.mode == "native_circle" then
      NATIVE_CIRCLETOOL:new(self, self.mode)
   else
      self:native_backup_startModeTool(modifiers)
   end
end

setmetatable = _G.setmetatable
type = _G.type

----------------------------------------------------------------------
-- basic shapes from goodies.lua
----------------------------------------------------------------------
function check_primary_is_line(model)
  local p = model:page()
  local prim = p:primarySelection()
  if not prim then model.ui:explain("no selection") return end
  local obj = p[prim]
  if obj:type() == "path" then
    local shape = obj:shape()
    if #shape == 1 then
      local s = shape[1]
      if s.type == "curve" then
        return prim, obj, s
      end
    end
  end
end

----------------------------------------------------------------------
-- basic shapes from tools.lua
----------------------------------------------------------------------
local function segment(v1, v2)
  return { type = "segment"; v1, v2 }
end

local function segmentshape(v1, v2)
  return { type="curve", closed=false; segment(v1, v2) }
end

local function path_from_points(points)

  local path_shape = { type="curve", closed = false; }

  for i = 2, #points do
    local p1 = points[i - 1]
    local p2 = points[i]
    local segment_shape = segment(p1, p2)
    path_shape[i - 1] = segment_shape
  end
  return path_shape
end

local function closed_path_from_points(points)

  local path_shape = { type="curve", closed = true; }

  if #points == 1 then
    local p = points[1]
    local segment_shape = segment(p, p)
    path_shape[1] = segment_shape
    return path_shape
  end

  for i = 2, #points do
    local p1 = points[i - 1]
    local p2 = points[i]
    local segment_shape = segment(p1, p2)
    path_shape[i - 1] = segment_shape
  end
  return path_shape
end

local function circleshape(center, radius)
   return { type="ellipse";
	    ipe.Matrix(radius, 0, 0, radius, center.x, center.y) }
end

----------------------------------------------------------------------
-- native representation computations
----------------------------------------------------------------------

function polar_coordinate_from(r, phi)
  return { radius = r, angle = phi}
end

function native_distance(v1, v2)

  if v1.radius == v2.radius and v1.angle == v2.angle then
    return 0.0
  end

  local delta_phi = math.pi - math.abs(math.pi - math.abs(v1.angle - v2.angle))

  return acosh((cosh(v1.radius) * cosh(v2.radius)) - (sinh(v1.radius) * sinh(v2.radius) * math.cos(delta_phi)))

end

-- Transform a point in Euclidean coordinates to a point in hyperbolic
-- native coordinates.
function transform_to_native(v)

  -- Get v relative to the origin.
  local v_relative_to_origin = v - reference_ray.origin

  -- Get radius and angle
  local radius = v_relative_to_origin:len() / reference_scale
  local angle = v_relative_to_origin:angle()

  return polar_coordinate_from(radius, angle)
end

-- Transform a point in hyperbolic native coordinates to Euclidean
-- coordinates.
function transform_from_native(v)

  local radius = v.radius
  local angle = v.angle

  -- Scale the radius
  radius = radius * reference_scale

  -- Convert the polar coordinates to euclidean ones.
  local x = radius * math.cos(angle);
  local y = radius * math.sin(angle);

  -- Get the point relative to the origin.
  return ipe.Vector(x, y) + reference_ray.origin
end

-- Rotate a point in hyperbolic polar coordinate around the origin by
-- angle phi.
function native_rotate_by(v, phi)
  local angle = math.fmod(v.angle + phi, 2.0 * math.pi)
  while angle < 0.0 do
    angle = angle + 2.0 * math.pi
  end
  return polar_coordinate_from(v.radius, angle)
end

-- Returns a point in hyperbolic polar coordinates that represents a
-- point which is obtained by applying the following translation to
-- the passed point v. The translation moves a point p on the origin
-- to the point p' whose radius is the absolute value of d. If d is
-- negative the angular coordinate of p' is π, otherwise it is 0.
function native_translate_horizontally_by(v, d)

  local current_v = polar_coordinate_from(v.radius, v.angle)

  if d == 0.0 then
    return v
  end

  -- Depending on whether or not the point lies on the x-axis, we have
  -- to do different things.
  if v.angle ~= math.pi and v.angle ~= 0.0 then
    -- Determine the reference point used for the translation.
    local ref = polar_coordinate_from(math.abs(d), 0.0)

    if d > 0.0 then
      ref.angle = math.pi
    end

    -- If the coordinate is below the x-axis, we mirror the point, on
    -- the x-axis, which makes things easier.

    if v.angle > math.pi then
      current_v.angle = (2.0 * math.pi) - current_v.angle
    end

    -- The radial coordinate is simply the distance between the
    -- reference point and the coordinate.

    local new_radius = native_distance(current_v, ref)

    local enumerator = (cosh(abs(d)) * cosh(new_radius)) - cosh(current_v.radius)

    local denominator = sinh(abs(d)) * sinh(new_radius)

    -- Determine the angular coordinate.
    local new_angle = 0.0

    new_angle = math.acos(enumerator / denominator)

    if new_angle ~= new_angle then
      new_angle = 0.0
    end

    if d < 0.0 then
      new_angle = math.pi - new_angle
    end

    if v.angle > math.pi then
      new_angle = (2.0 * math.pi) - new_angle
    end

    return polar_coordinate_from(new_radius, new_angle)

  else
    local new_angle = 0.0
    local new_radius = 0.0

    -- The coordinate lies on the x-axis so the translation only moves
    -- it along the axis.

    if v.angle == 0.0 then
      -- When we translate to far, we pass the origin and are on the
      -- other side.
      if v.radius + d < 0.0 then
        new_angle = math.pi
      end

      new_radius = abs(v.radius + d)
    else
      -- If we move to far, we pass the origin and are on the other
      -- side.

      if v.radius - d > 0.0 then
        new_angle = math.pi
      end

      new_radius = abs(v.radius - d)
    end

    return polar_coordinate_from(new_radius, new_angle)
  end
end

function theta(r1, r2, R)
  return math.acos((cosh(r1) * cosh(r2) - cosh(R)) / (sinh(r1) * sinh(r2)))
end

----------------------------------------------------------------------
-- LINTEOOL
----------------------------------------------------------------------

NATIVE_LINETOOL = {}
NATIVE_LINETOOL.__index = NATIVE_LINETOOL

function NATIVE_LINETOOL:new(model, mode)
  local tool = {}
  setmetatable(tool, NATIVE_LINETOOL)
  tool.model = model
  tool.mode = mode
  local v = model.ui:pos()
  tool.v = { v, v }
  tool.cur = 2
  model.ui:shapeTool(tool)
  tool.setColor(1.0, 0, 0)
  return tool
end

function NATIVE_LINETOOL:compute()
  -- I
  local v1 = self.v[1]
  local v2 = self.v[2]

  local native_v1 = transform_to_native(v1)
  local native_v2 = transform_to_native(v2)

  self.model.ui:explain("Hyperbolic length: " .. tostring(native_distance(native_v1, native_v2)), 0)

  -- Rotate 'both' points such that v1 lies on the x-axis.
  local native_v2_rotated = native_rotate_by(native_v2, -native_v1.angle)

  -- Translate 'both' points such that v1 lies in the origin.
  local native_v2_translated = native_translate_horizontally_by(native_v2_rotated, -native_v1.radius)

  -- 'Sample' points along the straight line from v1 to v2 and apply
  -- the reverse transformation of how v2 was transformed.

  local path = {}

  local resolution = 50

  for i = 1, resolution + 1 do
    local t = (i - 1) / resolution

    local p = polar_coordinate_from(t * native_v2_translated.radius, native_v2_translated.angle)

    -- Apply the inverse transformation.
    local p_translated = native_translate_horizontally_by(p, native_v1.radius)
    local p_rotated = native_rotate_by(p_translated, native_v1.angle)

    path[i] = transform_from_native(p_rotated)
  end

  -- path[resolution + 2] = transform_from_native(native_v2)

  local path_shape = path_from_points(path)

  self.shape = { path_shape }
end

function NATIVE_LINETOOL:mouseButton(button, modifiers, press)
  if not press then return end
  local v = self.model.ui:pos()
  -- refuse point identical to previous
  if v == self.v[self.cur - 1] then return end
  self.v[self.cur] = v
  self:compute()
  if self.cur == 2 then
    self.model.ui:finishTool()
    local obj = ipe.Path(self.model.attributes, self.shape, true)
    self.model:creation("create line", obj)
  else
    self.cur = self.cur + 1
    self.model.ui:update(false)
  end
end

function NATIVE_LINETOOL:mouseMove()
  self.v[self.cur] = self.model.ui:pos()
  self:compute()
  self.setShape(self.shape)
  self.model.ui:update(false) -- update tool
end

function NATIVE_LINETOOL:key(text, modifiers)
  if text == "\027" then
    self.model.ui:finishTool()
    return true
  else
    return false
  end
end

----------------------------------------------------------------------
-- CIRCLETOOL
----------------------------------------------------------------------

NATIVE_CIRCLETOOL = {}
NATIVE_CIRCLETOOL.__index = NATIVE_CIRCLETOOL

function NATIVE_CIRCLETOOL:new(model, mode)
  local tool = {}
  setmetatable(tool, NATIVE_CIRCLETOOL)
  tool.model = model
  tool.mode = mode
  local v = model.ui:pos()
  tool.v = { v, v }
  tool.cur = 2
  model.ui:shapeTool(tool)
  tool.setColor(1.0, 0, 0)
  return tool
end

function NATIVE_CIRCLETOOL:compute()
  -- I
  local v1 = self.v[1]
  local v2 = self.v[2]

  local native_center = transform_to_native(v1)
  local native_v2 = transform_to_native(v2)
  local radius = native_distance(native_center, native_v2)

  self.model.ui:explain("Hyperbolic radius: " .. tostring(radius), 0)

  if v1 == reference_ray.origin then
    -- The circle is centered in the origin, so it is a simple euclidean circle.
    self.shape = { circleshape(v1, (v2 - v1):len()) }
  else

    local resolution = 50

    -- If the center is not in the origin, we actually determine the
    -- points on the circle.
    --
    -- We first determine the points by pretending the node itself had
    -- angular coordinate 0.

    local r_min = math.max((radius - native_center.radius), (native_center.radius - radius))
    local r_max = native_center.radius + radius

    local step_size = math.max((r_max - r_min) / resolution, 0.01)

    local r = r_max
    local angle = 0.0

    local point = polar_coordinate_from(0.0, 0.0)

    -- When we get closer to the origin, we need finer steps in order to
    -- get a smooth circle.

    local additional_detail_threshold = 5.0 * step_size
    local additional_detail_points = resolution / 5.0
    local additional_step_size = step_size / additional_detail_points

    local path = {}
    local i = 1

    -- First we determine the circle points on one side of the x-axis.
    while r >= r_min do
      -- It's actually not a problem if this fails. In this case we
      -- simply use the previous angle.

      local new_angle = theta(native_center.radius, r, radius)

      if new_angle == new_angle and new_angle >= 0.0 then
        angle = new_angle
      end

      path[i] = polar_coordinate_from(r, angle)
      i = i + 1

      -- If we're close to the minimum radius, we need finer steps.
      if r > r_min + 0.00001 and r - r_min < additional_detail_threshold then

        if r <= r_min + step_size + 0.00001  then
          additional_step_size = additional_step_size / 5.0
        end

        local additional_r = r - additional_step_size

        while additional_r > r - step_size do
          local new_angle = theta(native_center.radius, additional_r, radius)

          if new_angle >= 0.0 then
            angle = new_angle
          end

          -- angle = 0.0

          if additional_r >= r_min then
            path[i] = polar_coordinate_from(additional_r, angle)
            i = i + 1
          end

          additional_r = additional_r - additional_step_size
        end

      end

      r = r - step_size
    end

    -- Now we add the point on the x-axis. Depending on whether the
    -- origin is contained in the circle, the angle of this points is
    -- either pi or 0.0
    local inner_point_angle = math.pi
    if native_center.radius > radius then
      inner_point_angle = 0.0
    end

    path[i] = polar_coordinate_from(r_min, inner_point_angle)
    i = i + 1

    -- Now we copy all points by mirroring them on the x-axis. We exclude the
    -- first and the last point, as they are lying on the x-axis. To obtain a
    -- valid path we need walk from the end of the vector to the start.

    local j = i - 2;
    while j > 0 do
      point = path[j]
      path[i] = polar_coordinate_from(point.radius, (2.0 * math.pi) - point.angle)
      i = i + 1
      j = j - 1
    end

    -- Finally we rotate all points around the origin to match the angular
    -- coordinate of the circle center.
    for i = 1, #path do
      point = native_rotate_by(path[i], native_center.angle)
      path[i] = transform_from_native(point)
    end

    if #path == 0 then
      path[1] = native_center
    end

    local path_shape = closed_path_from_points(path)

    self.shape = { path_shape }
  end
end

function NATIVE_CIRCLETOOL:mouseButton(button, modifiers, press)
  if not press then return end
  local v = self.model.ui:pos()
  -- refuse point identical to previous
  if v == self.v[self.cur - 1] then return end
  self.v[self.cur] = v
  self:compute()
  if self.cur == 2 then
    self.model.ui:finishTool()
    local obj = ipe.Path(self.model.attributes, self.shape, true)
    self.model:creation("create circle", obj)
  else
    self.cur = self.cur + 1
    self.model.ui:update(false)
  end
end

function NATIVE_CIRCLETOOL:mouseMove()
  self.v[self.cur] = self.model.ui:pos()
  self:compute()
  self.setShape(self.shape)
  self.model.ui:update(false) -- update tool
end

function NATIVE_CIRCLETOOL:key(text, modifiers)
  if text == "\027" then
    self.model.ui:finishTool()
    return true
  else
    return false
  end
end

function native_line_mode(model, num)
  if num == 2 then
    model.mode = "native_line_segment"
    model.ui:explain("Native Tool: line segment between two points")
  elseif num == 3 then
    model.mode = "native_circle"
    model.ui:explain("Native Tool: circle (center = first point, radius = distance between center and second point)")
  end
end

function set_reference_ray(model, num)

  local _, obj, shape = check_primary_is_line(model)

  local reference_ray_set_successfully = false

  -- Make sure obj and shape are non nil. They can be nil if the
  -- primary selection was not a curve.
  if (not (obj == nil)) and (not (shape == nil)) then

    local segment = shape[1]

    if segment["type"] == "segment" then

      -- Get the points from the first segment.
      local p1 = obj:matrix() * segment[1]
      local p2 = obj:matrix() * segment[2]

      reference_ray.origin = p1
      reference_ray.target = p2

      local dist = (reference_ray.origin - reference_ray.target):len()

      reference_scale = dist / 4

      -- Notify the user that the refernce ray was set.
      model.ui:explain("Set origin of hyperbolic plane to: " .. tostring(reference_ray.origin))

      reference_ray_set_successfully = true
    end
  end

  -- If we didn't update the reference ray, we warn the user.
  if not reference_ray_set_successfully then
    model:warning("Could not set reference ray. Ensure that your primary selection is a line.")
  end
end

function print_table(t)
  for key, value in pairs(t) do
    if type(value) == "table" then
      print("---")
      print("Key: " .. key)
      print_table(value)
      print("---")
    else
      print(key, value)
    end
  end
end

methods = {
   { label = "Set Reference Ray", run=set_reference_ray},
   -- { label = "line tool", run=native_line_mode},
   { label = "Line Segment Tool", run=native_line_mode},
   { label = "Circle Tool", run=native_line_mode},
   -- { label = "circle (by center + radius)", run=native_line_mode},
   -- { label = "circle (by radius + center)", run=native_line_mode},
}

shortcuts.ipelet_1_native = "N,R"
shortcuts.ipelet_2_native = "N,P"
shortcuts.ipelet_3_native = "N,O"
-- shortcuts.ipelet_4_native = "N,Shift+O"
-- shortcuts.ipelet_5_native = "N,Ctrl+O"
