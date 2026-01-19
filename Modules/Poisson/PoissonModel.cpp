/*  
 * This file is part of the tiberCAD module poisson.
 *
 * tiberCAD modules are licensed under the GNU General Public License v3.
 *
 * tiberCAD is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * tiberCAD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with tiberCAD. If not, see <http://www.gnu.org/licenses/>.
 */

/*!
 * \file PoissonModel.cpp
 * \brief tiberCAD poisson module implementation.
 *
 * \note This file is part of module poisson.
 */


#include "PoissonModel.h"
#include "ChargeDensityModel.h"

#include "tibercad/physics/misc/PolarizationModel.h"
#include "tibercad/physics/misc/PermittivityModel.h"

using namespace std;


TiberModelObject*
PoissonModel::_create(const ModelOptions& options, const void*)
{
  return new PoissonModel(options);
}


void
PoissonModel::_destroy(TiberModelObject* p)
{
  delete p;
}


PoissonModel*
PoissonModel::create(const Material* mat, const ModelOptions& options)
{
  string type("default");
  options.get_option("type", type);

  PoissonModel* pm = NULL;

  if (type == "default")
    // we create the default model from explicit creation method
    pm = PhysicalModel::create<PoissonModel>(_create, _destroy, mat, options);
  else
  {
    // there is no such model, at the moment
    type = "bulk_" + type;
    pm = PhysicalModel::create<PoissonModel>(type, mat, options);
  }

  return(pm);
}



void
PoissonModel::do_init(void)
{
  _permittivity = _permittivity_model->get_permittivity();
}

void
PoissonModel::do_calculate(void)
{
 

  _charge_density = 0.0;
  if (_charge_density_model != NULL)
    _charge_density = _charge_density_model->get_charge_density(get_element(), get_point());

  //Get total polarization 
  _polarization = 0;
  for (ID n = 0 ; n <_pm.size() ; n++)
  {
    _pm[n]->calculate(_elem,_point);
    _polarization += _pm[n]->get_polarization();
  }

  

}

void
PoissonModel::prepare_submodels(void)
{
  
  ModelOptions opts;
  opts.set_option("type", "constant");
  create_submodel(_permittivity_model, "permittivity", opts);
  
  // alternative way to create internal submodels:
  //
  // PermittivityModel* mod = PhysicalModel::create("permittivity", opts);
  // add_submodel("permittivity", mod)

  create_submodel(_charge_density_model, "charge_density");
  create_submodels(_pm, "polarization");

  // NOTE: all submodels are initialized automatically before calling do_init()
}
